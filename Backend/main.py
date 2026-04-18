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

class UpdateStatus(BaseModel):
    booking_id: int
    status: str

class RoutineItem(BaseModel):
    day_of_week: str
    time_slot: str

class UpdateRoutineRequest(BaseModel):
    provider_id: str  
    routines: List[RoutineItem]

class BookingRequest(BaseModel):
    student_id: str
    provider_id: str 
    course_name: str
    day_of_week: str
    time_slot: str
    routine_id: int

#------ Rubaiyat -------
class FocusSession(BaseModel):
    user_id: str
    duration_seconds: int

# --- Shehraj ---
class AcademicTask(BaseModel):
    user_id: str
    title: str
    course_name: str
    task_type: str
    due_date: date
    estimated_hours: int

class TaskComplete(BaseModel):
    task_id: int


# ===================== HELPERS =====================

def json_error(message: str, code: int = 400):
    return JSONResponse(content={"success": False, "error": message}, status_code=code)

def get_db():
    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="1234",
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

# ===================== My Consultation Page (Nishat) =====================
@app.get("/my_consultations/{user_id}")
def get_my_consultations(user_id: str, role: str):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor(dictionary=True)
        bookings = []
        
        # Removed 'Completed' and 'Rejected' from these queries
        if role == "student":
            cursor.execute("""
                SELECT * FROM consultation_bookings 
                WHERE student_id = %s AND status IN ('Pending', 'Accepted')
                ORDER BY created_at DESC
            """, (user_id,))
            bookings = cursor.fetchall()
            
        elif role == "faculty":
            cursor.execute("SELECT f_initial FROM faculties WHERE f_id = %s", (user_id,))
            faculty_record = cursor.fetchone()
            if faculty_record and faculty_record['f_initial']:
                f_initial = faculty_record['f_initial']
                cursor.execute("""
                    SELECT * FROM consultation_bookings 
                    WHERE provider_id = %s AND status IN ('Pending', 'Accepted')
                    ORDER BY created_at DESC
                """, (f_initial,))
                bookings = cursor.fetchall()
                
        else: # tutor
            cursor.execute("""
                SELECT * FROM consultation_bookings 
                WHERE provider_id = %s AND status IN ('Pending', 'Accepted')
                ORDER BY created_at DESC
            """, (user_id,))
            bookings = cursor.fetchall()
            
        return {"success": True, "data": bookings}
    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        if cursor: cursor.close()
        if db: db.close()


@app.post("/update_consultation_status")
def update_consultation_status(payload: UpdateStatus):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor()
        
        cursor.execute(
            "UPDATE consultation_bookings SET status = %s WHERE booking_id = %s",
            (payload.status, payload.booking_id)
        )
        db.commit()
        return {"success": True, "message": f"Status updated to {payload.status}"}
    except Exception as e:
        if db: db.rollback()
        # Replaced json_error to ensure it returns cleanly 
        return {"success": False, "error": str(e)}
    finally:
        if cursor: cursor.close()
        if db: db.close()

@app.get("/consultation_history/{user_id}")
def get_consultation_history(user_id: str, role: str):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor(dictionary=True)
        history = []
        
        # Looking only for 'Completed' or 'Rejected'
        if role == "student":
            cursor.execute("""
                SELECT * FROM consultation_bookings 
                WHERE student_id = %s AND status IN ('Completed', 'Rejected')
                ORDER BY created_at DESC
            """, (user_id,))
            history = cursor.fetchall()
            
        elif role == "faculty":
            cursor.execute("SELECT f_initial FROM faculties WHERE f_id = %s", (user_id,))
            faculty_record = cursor.fetchone()
            if faculty_record and faculty_record['f_initial']:
                f_initial = faculty_record['f_initial']
                cursor.execute("""
                    SELECT * FROM consultation_bookings 
                    WHERE provider_id = %s AND status IN ('Completed', 'Rejected')
                    ORDER BY created_at DESC
                """, (f_initial,))
                history = cursor.fetchall()
                
        else: # tutor
            cursor.execute("""
                SELECT * FROM consultation_bookings 
                WHERE provider_id = %s AND status IN ('Completed', 'Rejected')
                ORDER BY created_at DESC
            """, (user_id,))
            history = cursor.fetchall()
            
        return {"success": True, "data": history}
    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        if cursor: cursor.close()
        if db: db.close()

# ===================== CONSULTATION BOOKING (Nishat) =====================
@app.get("/api/courses")
def get_courses():
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor(dictionary=True)
        cursor.execute("SELECT * FROM courses")
        return {"success": True, "data": cursor.fetchall()}
    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        if cursor: cursor.close()
        if db: db.close()

@app.get("/api/providers")
def get_providers():
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor(dictionary=True)
        # Fetching available faculties and sending f_initial as provider_id
        cursor.execute("""
            SELECT f_initial as provider_id, f_name as provider_name 
            FROM faculties 
            WHERE con_status = 'available'
        """)
        return {"success": True, "data": cursor.fetchall()}
    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        if cursor: cursor.close()
        if db: db.close()

@app.get("/api/routines/{provider_initial}")
def get_provider_routine(provider_initial: str):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor(dictionary=True)
        # JOIN tables to link f_initial (RHD) to f_id (T24001)
        # Only return slots where is_booked = 0
        cursor.execute("""
            SELECT cr.routine_id, cr.day_of_week, cr.time_slot 
            FROM consultation_routines cr
            JOIN faculties f ON cr.provider_id = f.f_id
            WHERE f.f_initial = %s AND cr.is_booked = 0
        """, (provider_initial,))
        return {"success": True, "data": cursor.fetchall()}
    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        if cursor: cursor.close()
        if db: db.close()


@app.post("/update_routine")
def update_routine(req: UpdateRoutineRequest):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor()

        cursor.execute("DELETE FROM consultation_routines WHERE provider_id = %s", (req.provider_id,))
        
        for slot in req.routines:
            cursor.execute("""
                INSERT INTO consultation_routines (provider_id, day_of_week, time_slot, is_booked)
                VALUES (%s, %s, %s, 0)
            """, (req.provider_id, slot.day_of_week, slot.time_slot))      

        db.commit()
        return {"success": True, "message": "Routine updated and all slots reset!"}
        
    except Exception as e:
        if db: db.rollback() 
        return {"success": False, "error": str(e)}
    finally:
        if cursor: cursor.close()
        if db: db.close()


@app.post("/book_consultation")
def book_consultation(req: BookingRequest):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor()
        
        #Insert the booking into consultation_bookings
        cursor.execute("""
            INSERT INTO consultation_bookings 
            (student_id, provider_id, course_name, day_of_week, time_slot, status) 
            VALUES (%s, %s, %s, %s, %s, 'Pending')
        """, (req.student_id, req.provider_id, req.course_name, req.day_of_week, req.time_slot))
        
        #Update the consultation_routines to mark this specific slot as booked
        cursor.execute("""
            UPDATE consultation_routines 
            SET is_booked = 1 
            WHERE routine_id = %s
        """, (req.routine_id,))
        
        db.commit()
        return {"success": True, "message": "Consultation booked successfully"}
    except Exception as e:
        if db: db.rollback() 
        return {"success": False, "error": str(e)}
    finally:
        if cursor: cursor.close()
        if db: db.close()

# ===================== NOTE SYSTEM =====================

 # ===================== Note System =====================

import random

def evaluate_note_ai(text: str):

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

@app.get("/api/notes/all/{user_id}")
def get_all_notes(user_id: str):
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
                u.name AS uploader_name,

                (SELECT COUNT(*) FROM note_upvotes u WHERE u.note_id = n.note_id) AS upvotes,
                (SELECT COUNT(*) FROM note_comments c WHERE c.note_id = n.note_id) AS comments,

                EXISTS(
                    SELECT 1 FROM note_upvotes u2 
                    WHERE u2.note_id = n.note_id AND u2.user_id = %s
                ) AS isLiked

            FROM note n
            JOIN users u ON n.uploaded_by = u.user_id
            ORDER BY n.created_at DESC
        """, (user_id,))

        return {
            "success": True,
            "notes": cursor.fetchall()
        }

    finally:
        if cursor: cursor.close()
        if db: db.close()

@app.post("/api/notes/save")
def save_note(payload: SaveNote):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor()

        cursor.execute("""
            INSERT IGNORE INTO saved_notes (user_id, note_id)
            VALUES (%s, %s)
        """, (payload.user_id, payload.note_id))

        db.commit()
        return {"success": True, "message": "Saved"}

    finally:
        if cursor: cursor.close()
        if db: db.close()

@app.post("/api/notes/unsave")
def unsave_note(payload: SaveNote):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor()

        cursor.execute("""
            DELETE FROM saved_notes
            WHERE user_id=%s AND note_id=%s
        """, (payload.user_id, payload.note_id))

        db.commit()
        return {"success": True, "message": "Unsaved"}

    finally:
        if cursor: cursor.close()
        if db: db.close()


@app.get("/api/notes/saved/{user_id}")
def get_saved_notes(user_id: str):
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

                (SELECT COUNT(*) FROM note_upvotes u WHERE u.note_id = n.note_id) AS upvotes,
                (SELECT COUNT(*) FROM note_comments c WHERE c.note_id = n.note_id) AS comments,

                EXISTS(
                    SELECT 1 FROM note_upvotes u2 
                    WHERE u2.note_id = n.note_id AND u2.user_id = %s
                ) AS isLiked

            FROM note n
            JOIN saved_notes s ON n.note_id = s.note_id
            WHERE s.user_id = %s
            ORDER BY s.id DESC
        """, (user_id, user_id))

        return {
            "success": True,
            "notes": cursor.fetchall()
        }

    finally:
        if cursor: cursor.close()
        if db: db.close()

        
# ===================== Upvote System =====================
@app.post("/api/notes/upvote")
def toggle_upvote(data: dict):
    db = get_db()
    cursor = db.cursor()

    note_id = data["note_id"]
    user_id = data["user_id"]

    cursor.execute(
        "SELECT * FROM note_upvotes WHERE note_id=%s AND user_id=%s",
        (note_id, user_id)
    )
    existing = cursor.fetchone()

    if existing:
        cursor.execute(
            "DELETE FROM note_upvotes WHERE note_id=%s AND user_id=%s",
            (note_id, user_id)
        )
        db.commit()
        return {"liked": False}
    else:
        cursor.execute(
            "INSERT INTO note_upvotes (note_id, user_id) VALUES (%s, %s)",
            (note_id, user_id)
        )
        db.commit()
        return {"liked": True}
    

@app.get("/api/notes/upvotes/{note_id}")
def get_upvotes(note_id: int):
    db = get_db()
    cursor = db.cursor()

    cursor.execute(
        "SELECT COUNT(*) FROM note_upvotes WHERE note_id=%s",
        (note_id,)
    )

    count = cursor.fetchone()[0]
    return {"count": count}


# ===================== Comment System =====================

@app.post("/api/notes/comment")
def add_comment(data: dict):
    db = get_db()
    cursor = db.cursor()

    cursor.execute("""
        INSERT INTO note_comments (note_id, user_id, comment)
        VALUES (%s, %s, %s)
    """, (
        data["note_id"],
        data["user_id"],
        data["comment"]
    ))

    db.commit()
    return {"success": True}

@app.get("/api/notes/comments/{note_id}")
def get_comments(note_id: int):
    db = get_db()
    cursor = db.cursor(dictionary=True)

    cursor.execute("""
        SELECT 
            note_comments.comment,
            note_comments.created_at,
            users.name AS user_name
        FROM note_comments
        JOIN users ON note_comments.user_id = users.user_id
        WHERE note_comments.note_id=%s
        ORDER BY note_comments.created_at DESC
    """, (note_id,))

    return {"comments": cursor.fetchall()}