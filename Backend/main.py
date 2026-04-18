from fastapi import FastAPI, UploadFile, File, Form, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, field_validator
from typing import Dict, List, Optional
from datetime import date, timedelta
import mysql.connector
import os
import shutil
import uvicorn
import random

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)
app = FastAPI()

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

class UpdateStatus(BaseModel):
    booking_id: int
    status: str

class FocusSession(BaseModel):
    user_id: str
    duration_seconds: int

class AcademicTask(BaseModel):
    user_id: str
    title: str
    course_name: str
    task_type: str
    due_date: date
    estimated_hours: int

class TaskComplete(BaseModel):
    task_id: int

class CourseOutline(BaseModel):
    user_id: str
    course_code: str
    course_name: str
    stream: str
    status: str
    credits: int = 3

class DeleteCourse(BaseModel):
    user_id: str
    course_code: str

# ===================== HELPERS =====================
def json_error(message: str, code: int = 400):
    return JSONResponse(content={"success": False, "error": message}, status_code=code)

def get_db():
    return mysql.connector.connect(
        host="127.0.0.1",
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
            "SELECT f_id AS id, f_name AS name, f_initial AS initial, con_status AS con_status FROM faculties WHERE f_id=%s",
            (user_id,)
        )
        faculty = cursor.fetchone()
        if faculty:
            return {"success": True, "role": "faculty", "person": faculty}

        cursor.execute(
            "SELECT st_id AS id, st_name AS name, st_initial AS initial, st_con_status AS con_status FROM student_tutors WHERE st_id=%s",
            (user_id,)
        )
        tutor = cursor.fetchone()
        if tutor:
            return {"success": True, "role": "tutor", "person": tutor}

        cursor.execute(
            "SELECT user_id AS id, name AS name, email AS email FROM users WHERE user_id=%s",
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

# ===================== CONSULTATIONS SYSTEM =====================
@app.post("/save_routine")
def save_routine(payload: SaveRoutine):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor()
        cursor.execute("DELETE FROM consultation_routines WHERE provider_id = %s AND is_booked = FALSE", (payload.provider_id,))
        insert_query = "INSERT IGNORE INTO consultation_routines (provider_id, day_of_week, time_slot, is_booked) VALUES (%s, %s, %s, FALSE)"
        insert_data = [(payload.provider_id, day, t) for day, times in payload.routine.items() for t in times]
        if insert_data: cursor.executemany(insert_query, insert_data)
        db.commit()
        return {"success": True, "message": "Routine saved successfully"}
    except Exception as e:
        if db: db.rollback() 
        return json_error(str(e))
    finally:
        if cursor: cursor.close()
        if db: db.close()

# ===================== NOTE SYSTEM =====================
def evaluate_note_ai(text: str):
    return {
        "score": random.randint(60, 95), "completeness": random.randint(60, 95),
        "keyword_coverage": random.randint(60, 95), "clarity": random.randint(60, 95),
        "formatting": random.randint(60, 95), "feedback": "Good structure but needs more key definitions"
    }

@app.post("/api/notes/upload")
async def upload_note(title: str = Form(...), description: str = Form(...), course: str = Form(...), uploader_id: str = Form(...), file: UploadFile = File(...)):
    db = cursor = None
    try:
        file_location = os.path.join(UPLOAD_DIR, file.filename)
        with open(file_location, "wb") as f: shutil.copyfileobj(file.file, f)
        ai_result = evaluate_note_ai(description)
        db = get_db()
        cursor = db.cursor()
        cursor.execute("""
            INSERT INTO note (title, description, course, file_path, filename, file_size, uploaded_by, ai_score, completeness, keyword_coverage, clarity, formatting, feedback)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        """, (title, description, course, file_location, file.filename, os.path.getsize(file_location), uploader_id, ai_result["score"], ai_result["completeness"], ai_result["keyword_coverage"], ai_result["clarity"], ai_result["formatting"], ai_result["feedback"]))
        db.commit()
        return {"success": True, "message": "Note uploaded + AI evaluated", "ai_score": ai_result["score"]}
    except Exception as e: return json_error(str(e))
    finally:
        if cursor: cursor.close()
        if db: db.close()

# ===================== FOCUS MODE =====================
@app.post("/save_focus_session")
def save_focus_session(session: FocusSession):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor()
        cursor.execute("INSERT INTO focus_sessions (user_id, duration_seconds) VALUES (%s, %s)", (session.user_id, session.duration_seconds))
        db.commit()
        return {"success": True, "message": "Focus session saved"}
    except Exception as e:
        if db: db.rollback()
        return json_error(str(e))
    finally:
        if cursor: cursor.close()
        if db: db.close()

# ===================== SMART STUDY LOAD ANALYZER =====================
@app.post("/api/tasks/add")
def add_task(task: AcademicTask):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor()
        cursor.execute("INSERT INTO academic_tasks (user_id, title, course_name, task_type, due_date, estimated_hours) VALUES (%s, %s, %s, %s, %s, %s)", (task.user_id, task.title, task.course_name, task.task_type, task.due_date, task.estimated_hours))
        db.commit()
        return {"success": True, "message": "Task added successfully"}
    except Exception as e: return json_error(str(e))
    finally:
        if cursor: cursor.close()
        if db: db.close()

# ===================== COURSE OUTLINE SYSTEM =====================
@app.post("/api/courses/update")
def update_course_outline(course: CourseOutline):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor()
        query = """
            INSERT INTO course_outlines (user_id, course_code, course_name, stream, status, credits)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE 
            status = VALUES(status), course_name = VALUES(course_name), stream = VALUES(stream)
        """
        cursor.execute(query, (course.user_id, course.course_code, course.course_name, course.stream, course.status, course.credits))
        db.commit()
        return {"success": True, "message": "Course outline updated"}
    except Exception as e: return json_error(str(e))
    finally:
        if cursor: cursor.close()
        if db: db.close()

@app.get("/api/courses/progress/{user_id}")
def get_course_progress(user_id: str):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor(dictionary=True)
        cursor.execute("SELECT * FROM course_outlines WHERE user_id = %s", (user_id,))
        courses = cursor.fetchall()
        if not courses:
            return {"success": True, "completed_count": 0, "remaining_count": 0, "progress_percent": 0, "courses": []}
        completed = [c for c in courses if c['status'] == 'Completed']
        percent = round((len(completed) / len(courses)) * 100, 1) if courses else 0
        return {"success": True, "completed_count": len(completed), "remaining_count": len(courses)-len(completed), "progress_percent": percent, "courses": courses}
    except Exception as e: return json_error(str(e))
    finally:
        if cursor: cursor.close()
        if db: db.close()

@app.post("/api/courses/delete")
def delete_course_outline(payload: DeleteCourse):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor()
        cursor.execute("DELETE FROM course_outlines WHERE user_id=%s AND course_code=%s", (payload.user_id, payload.course_code))
        db.commit()
        return {"success": True, "message": "Course deleted"}
    except Exception as e: return json_error(str(e))
    finally:
        if cursor: cursor.close()
        if db: db.close()

if __name__ == "__main__":
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)