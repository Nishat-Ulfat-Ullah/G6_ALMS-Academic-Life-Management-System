from fastapi import FastAPI, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, FileResponse
from pydantic import BaseModel, field_validator
from typing import Dict, List

import mysql.connector
import os
import shutil
import uvicorn
UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)
app = FastAPI()


from fastapi.staticfiles import StaticFiles

app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  
    allow_methods=["*"],
    allow_headers=["*"],
)

# ===================== MODELS =====================
class User(BaseModel):
    user_id: str
    name: str
    email: str
    password: str
    @field_validator('email')
    @classmethod
    def validate_email(cls, v):
        if not v.endswith('bracu.ac.bd'):
            raise ValueError('Email must end with bracu.ac.bd')
        return v

    @field_validator('password')
    @classmethod
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters long')
        return v

class LoginUser(BaseModel):
    email: str
    password: str

class Consultation(BaseModel):
    student_id: str
    course_name: str
    faculty_name: str
    day: str
    time_slot: str


class Faculty(BaseModel):
    f_id: str
    f_name: str
    f_initial: str
    con_status: str

class SaveNote(BaseModel):
    user_id: str
    note_id: int

class SaveRoutine(BaseModel):
    provider_id: str
    routine: Dict[str, List[str]]

# ===================== HELPERS =====================
def json_error(message: str, code: int = 400):
    return JSONResponse(content={"success": False, "error": message}, status_code=code)

def get_db():
    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="123",
        database="project"
    )


# ===================== USER SYSTEM =====================
@app.post("/register")
def register(user: User):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor()
        cursor.execute(
            "INSERT INTO users (user_id, name, email, password) VALUES (%s, %s, %s, %s)",
            (user.user_id, user.name, user.email, user.password)
        )
        db.commit()
        return {"success": True, "message": "Registration successful"}
    except Exception as e:
        return json_error(str(e))
    finally:
        if cursor: cursor.close()
        if db: db.close()

@app.post("/login")
def login(user: LoginUser):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor(dictionary=True)
        cursor.execute("SELECT * FROM users WHERE email=%s", (user.email,))
        db_user = cursor.fetchone()
        if not db_user:
            return {"success": False, "message": "User not found"}
        if user.password != db_user["password"]:
            return {"success": False, "message": "Incorrect password"}
        return {
            "success": True,
            "message": "Login successful",
            "user": {
                "user_id": db_user["user_id"],
                "name": db_user["name"],
                "email": db_user["email"]
            }
        }
    except Exception as e:
        return json_error(str(e))
    finally:
        if cursor: cursor.close()
        if db: db.close()


@app.get("/role/{user_id}")
def check_role(user_id: str):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor(dictionary=True)

        cursor.execute(
            "SELECT f_id AS id, f_name AS name, f_initial AS initial, con_status AS con_status "
            "FROM faculties WHERE f_id=%s",
            (user_id,)
        )
        faculty = cursor.fetchone()
        if faculty:
            return {"success": True, "role": "faculty", "person": faculty}

        cursor.execute(
            "SELECT st_id AS id, st_name AS name, st_initial AS initial, st_con_status AS con_status "
            "FROM student_tutors WHERE st_id=%s",
            (user_id,)
        )
        tutor = cursor.fetchone()
        if tutor:
            return {"success": True, "role": "tutor", "person": tutor}

        cursor.execute(
            "SELECT user_id AS id, name AS name, email AS email "
            "FROM users WHERE user_id=%s",
            (user_id,)
        )
        student = cursor.fetchone()
        if student:
            return {"success": True, "role": "student", "person": student}

        return {"success": False, "message": "User not found"}
    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        if cursor: cursor.close()
        if db: db.close()

# ===================== Consultations SYSTEM =====================

@app.post("/save_routine")
def save_routine(payload: SaveRoutine):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor()
        
        cursor.execute(
            "DELETE FROM consultation_routines WHERE provider_id = %s AND is_booked = FALSE",
            (payload.provider_id,)
        )

        insert_query = """
            INSERT IGNORE INTO consultation_routines (provider_id, day_of_week, time_slot, is_booked)
            VALUES (%s, %s, %s, FALSE)
        """
        
        insert_data = []
        for day, times in payload.routine.items():
            for time_slot in times:
                insert_data.append((payload.provider_id, day, time_slot))

        if insert_data:
            cursor.executemany(insert_query, insert_data)

        db.commit()
        return {"success": True, "message": "Routine saved successfully"}

    except Exception as e:
        if db: 
            db.rollback() 
        return json_error(str(e))
    finally:
        if cursor: cursor.close()
        if db: db.close()


 # ===================== Note System =====================

import random

def evaluate_note_ai(text: str):
    """
    Replace this with OpenAI later
    For now: dummy AI scoring
    """

    return {
        "score": random.randint(60, 95),
        "completeness": random.randint(60, 95),
        "keyword_coverage": random.randint(60, 95),
        "clarity": random.randint(60, 95),
        "formatting": random.randint(60, 95),
        "feedback": "Good structure but needs more key definitions"
    }

@app.post("/api/notes/upload")
async def upload_note(
    title: str = Form(...),
    description: str = Form(...),
    course: str = Form(...),
    uploader_id: str = Form(...),
    file: UploadFile = File(...)
):
    db = cursor = None
    try:
        file_location = os.path.join(UPLOAD_DIR, file.filename)
        with open(file_location, "wb") as f:
            shutil.copyfileobj(file.file, f)

        # ================= AI STEP =================
        ai_result = evaluate_note_ai(description)

        db = get_db()
        cursor = db.cursor()

        cursor.execute("""
            INSERT INTO note 
            (title, description, course, file_path, filename, file_size, uploaded_by,
             ai_score, completeness, keyword_coverage, clarity, formatting, feedback)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        """, (
            title,
            description,
            course,
            file_location,
            file.filename,
            os.path.getsize(file_location),
            uploader_id,

            ai_result["score"],
            ai_result["completeness"],
            ai_result["keyword_coverage"],
            ai_result["clarity"],
            ai_result["formatting"],
            ai_result["feedback"]
        ))

        db.commit()

        return {
            "success": True,
            "message": "Note uploaded + AI evaluated",
            "ai_score": ai_result["score"]
        }

    except Exception as e:
        return json_error(str(e))
    finally:
        if cursor: cursor.close()
        if db: db.close()

@app.get("/api/notes/all")
def get_all_notes():
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor(dictionary=True)

        cursor.execute("""
            SELECT 
                n.note_id,
                n.title,
                n.description,
                n.course,
                n.file_path,
                n.filename,
                n.file_size,
                n.uploaded_by,
                n.created_at,
                n.ai_score,
                n.completeness,
                n.keyword_coverage,
                n.clarity,
                n.formatting,
                n.feedback,
                u.name AS uploader_name
            FROM note n
            JOIN users u ON n.uploaded_by = u.user_id
            ORDER BY n.created_at DESC
        """)

        return {"success": True, "notes": cursor.fetchall()}

    finally:
        if cursor: cursor.close()
        if db: db.close()