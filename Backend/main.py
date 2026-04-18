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


#------ Nishat --------
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


# ===================== CONSULTATIONS SYSTEM (Nishat) =====================
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

        ai_result = evaluate_note_ai(description)

        db = get_db()
        cursor = db.cursor()

        cursor.execute("""
            INSERT INTO note 
            (title, description, course, file_path, filename, file_size, uploaded_by,
             ai_score, completeness, keyword_coverage, clarity, formatting, feedback)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        """, (
            title, description, course, file_location, file.filename,
            os.path.getsize(file_location), uploader_id,
            ai_result["score"], ai_result["completeness"], ai_result["keyword_coverage"],
            ai_result["clarity"], ai_result["formatting"], ai_result["feedback"]
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
            SELECT n.*, u.name AS uploader_name
            FROM note n
            JOIN users u ON n.uploaded_by = u.user_id
            ORDER BY n.created_at DESC
        """)

        return {"success": True, "notes": cursor.fetchall()}

    finally:
        if cursor: cursor.close()
        if db: db.close()

#focus mode session
@app.post("/save_focus_session")
def save_focus_session(session: FocusSession):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor()
        
        
        cursor.execute(
            "INSERT INTO focus_sessions (user_id, duration_seconds) VALUES (%s, %s)",
            (session.user_id, session.duration_seconds)
        )
        db.commit()
        return {"success": True, "message": "Focus session saved"}
    except Exception as e:
        if db: 
            db.rollback()
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
        cursor.execute("""
            INSERT INTO academic_tasks (user_id, title, course_name, task_type, due_date, estimated_hours)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (task.user_id, task.title, task.course_name, task.task_type, task.due_date, task.estimated_hours))
        db.commit()
        return {"success": True, "message": "Task added successfully"}
    except Exception as e:
        return json_error(str(e))
    finally:
        if cursor: cursor.close()
        if db: db.close()

@app.get("/api/study_load/{user_id}")
def analyze_study_load(user_id: str):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor(dictionary=True)
        
        cursor.execute("""
            SELECT * FROM academic_tasks 
            WHERE user_id = %s AND is_completed = FALSE AND due_date >= CURDATE()
            ORDER BY due_date ASC
        """, (user_id,))
        tasks = cursor.fetchall()

        if not tasks:
            return {"success": True, "message": "No upcoming deadlines. Relax!", "summary": None, "distribution_plan": []}

        today = date.today()
        total_hours_needed = sum(t["estimated_hours"] for t in tasks)
        exam_count = sum(1 for t in tasks if t["task_type"] == 'Exam')
        deadline_count = len(tasks)
        
        latest_deadline = max(t["due_date"] for t in tasks)
        days_available = (latest_deadline - today).days
        if days_available <= 0: days_available = 1

        daily_hours_recommended = round(total_hours_needed / days_available, 1)

        if daily_hours_recommended > 6 or exam_count >= 2:
            stress_level = "Critical: High risk of burnout. Focus only on priority items."
        elif daily_hours_recommended > 3:
            stress_level = "Moderate: Steady daily effort required."
        else:
            stress_level = "Light: Easily manageable workload."

        study_plan = []
        for task in tasks:
            days_left = (task["due_date"] - today).days
            urgency = "High" if days_left <= 3 or task["task_type"] == "Exam" else "Normal"
            
            study_plan.append({
                "task": task["title"],
                "course": task["course_name"],
                "type": task["task_type"],
                "days_left": max(0, days_left),
                "urgency": urgency,
                "suggested_action": f"Dedicate {round(task['estimated_hours']/max(1, days_left), 1)} hrs/day starting today."
            })

        return {
            "success": True,
            "summary": {
                "total_deadlines": deadline_count,
                "upcoming_exams": exam_count,
                "total_estimated_hours": total_hours_needed,
                "recommended_daily_study_hours": daily_hours_recommended,
                "workload_status": stress_level
            },
            "distribution_plan": study_plan
        }
    except Exception as e:
        return json_error(str(e))
    finally:
        if cursor: cursor.close()
        if db: db.close()

# --- NEW: Delete Task Endpoint ---
@app.delete("/api/tasks/delete")
def delete_task(user_id: str = Query(...), title: str = Query(...)):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor()
        # We find the task by user_id and title
        cursor.execute(
            "DELETE FROM academic_tasks WHERE user_id = %s AND title = %s",
            (user_id, title)
        )
        db.commit()
        
        # Check if anything was actually deleted
        if cursor.rowcount == 0:
            return {"success": False, "message": "Task not found"}
            
        return {"success": True, "message": "Task deleted successfully"}
    except Exception as e:
        return json_error(str(e))
    finally:
        if cursor: cursor.close()
        if db: db.close()

if __name__ == "__main__":
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)