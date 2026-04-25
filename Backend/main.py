from fastapi import FastAPI, UploadFile, File, Form, Query, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, FileResponse
from pydantic import BaseModel, field_validator
from typing import Dict, List
from datetime import date, timedelta
from typing import Optional
from pytrends.request import TrendReq
from mappings import CURRICULUM_MAP, ARXIV_CATEGORY_MAP, COURSE_SKILL_MAP
import json
import requests
import xml.etree.ElementTree as ET
import mysql.connector
import os
import shutil
import uvicorn
import re

from dotenv import load_dotenv

load_dotenv()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

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

class UpdateStatusRequest(BaseModel):
    booking_id: int
    status: str
    summary: Optional[str] = None

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


class PerformanceUpdate(BaseModel):
    user_id: str
    attendance_count: int
    cgpa: float
    missed_deadlines: int
    low_quizzes: int

class StudentPerformance(BaseModel):
    user_id: str
    attendance_count: int
    total_classes: int
    cgpa: float
    missed_deadlines: int
    total_deadlines: int
    low_quizzes: int
    total_quizzes: int

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
#THESIS
class UserInterest(BaseModel):
    user_id: str
    interests: List[str]


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
def update_consultation_status(req: UpdateStatusRequest):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor()
        
        # If it's Completed and has a summary, update both status and summary
        if req.status == 'Completed' and req.summary is not None:
            cursor.execute("""
                UPDATE consultation_bookings 
                SET status = %s, summary = %s 
                WHERE booking_id = %s
            """, (req.status, req.summary, req.booking_id))
        else:
            # Otherwise, just update the status (for Accepted/Rejected)
            cursor.execute("""
                UPDATE consultation_bookings 
                SET status = %s 
                WHERE booking_id = %s
            """, (req.status, req.booking_id))
            
        db.commit()
        return {"success": True, "message": f"Status updated to {req.status}"}
    except Exception as e:
        if db: db.rollback()
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


@app.get("/api/academic_risk/{user_id}")
def get_academic_risk(user_id: str):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor(dictionary=True)
        
        cursor.execute("SELECT * FROM student_performance WHERE user_id = %s", (user_id,))
        stats = cursor.fetchone()

        if not stats:
            return {
                "success": True, 
                "risk_score": 0, 
                "zone": "Low", 
                "suggestion": "No data found. Keep studying!",
                "details": {"attendance": 0, "total_classes": 20, "cgpa": 0.0, "missed_deadlines": 0, "total_deadlines": 7, "low_quizzes": 0, "total_quizzes": 4}
            }

        # Calculation Logic
        att_rate = stats["attendance_count"] / stats["total_classes"]
        
        # Risk points
        att_risk = 25 if att_rate < 0.75 else 0
        cgpa_risk = 25 if float(stats["cgpa"]) < 3.0 else 0
        deadline_risk = min(stats["missed_deadlines"] * 12.5, 25)
        quiz_risk = min(stats["low_quizzes"] * 12.5, 25)
        
        total_score = att_risk + cgpa_risk + deadline_risk + quiz_risk

        if total_score >= 70:
            zone, suggestion = "High", "Critical risk: Please consult your faculty advisor."
        elif total_score >= 40:
            zone, suggestion = "Medium", "Moderate risk: Improve attendance and quiz scores."
        else:
            zone, suggestion = "Low", "Low risk: You are performing well!"

        return {
            "success": True,
            "risk_score": total_score,
            "zone": zone,
            "suggestion": suggestion,
            "details": {
                "attendance": stats["attendance_count"],
                "total_classes": stats["total_classes"],
                "cgpa": float(stats["cgpa"]),
                "missed_deadlines": stats["missed_deadlines"],
                "total_deadlines": stats["total_deadlines"],
                "low_quizzes": stats["low_quizzes"],
                "total_quizzes": stats["total_quizzes"]
            }
        }
    except Exception as e:
        return {"success": False, "error": str(e)}
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


# ===================== THESIS RECOMMENDER SYSTEM =====================

# --- THE SCRAPER  ---
def fetch_real_research_from_arxiv(interest_tags):
    try:
        if not interest_tags:
            interest_tags = ["Artificial Intelligence"]

        search_query = "+OR+".join(
            [f"all:{tag.replace(' ', '+')}" for tag in interest_tags]
        )

        # Increase max_results from 15 to 30
        url = f"http://export.arxiv.org/api/query?search_query={search_query}&start=0&max_results=30"

        response = requests.get(url, timeout=10)
        if response.status_code != 200:
            return []

        root = ET.fromstring(response.content)
        results = []
        ns = {
            'atom': 'http://www.w3.org/2005/Atom',
            'arxiv': 'http://arxiv.org/schemas/atom'
        }

        for entry in root.findall('atom:entry', ns):
            title_node = entry.find('atom:title', ns)
            id_node = entry.find('atom:id', ns)
            summary_node = entry.find('atom:summary', ns)  # grab abstract too

            if title_node is None or id_node is None:
                continue

            title = title_node.text.strip()
            link = id_node.text.strip()
            summary = summary_node.text.strip()[:200] if summary_node is not None else ""

            category_node = entry.find('arxiv:primary_category', ns)
            raw = category_node.attrib["term"] if category_node is not None else "cs.AI"
            domain = ARXIV_CATEGORY_MAP.get(raw, raw)

            results.append({
                "topic": title,
                "domain": domain,
                "url": link,
                "summary": summary   # now includes abstract snippet
            })

        return results

    except Exception as e:
        print("ARXIV ERROR:", e)
        return []
# --- ENDPOINTS ---

@app.post("/api/interests/update")
def update_interests(data: UserInterest):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor()
        # Clean out old interests and insert new ones
        cursor.execute("DELETE FROM user_interests WHERE user_id = %s", (data.user_id,))
        for tag in data.interests:
            cursor.execute("INSERT INTO user_interests (user_id, interest_tag) VALUES (%s, %s)", (data.user_id, tag))
        db.commit()
        return {"success": True}
    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        if cursor: cursor.close()
        if db: db.close()

@app.get("/api/interests/{user_id}")
def get_user_interests(user_id: str):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor(dictionary=True)
        cursor.execute("SELECT interest_tag FROM user_interests WHERE user_id=%s", (user_id,))
        # Extract just the strings into a list
        interests = [row['interest_tag'] for row in cursor.fetchall()]
        return {"success": True, "interests": interests}
    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        if cursor: cursor.close(); db.close()

def extract_skills(courses_raw):
    skills = []

    for c in courses_raw:
        code = str(c["course_code"])

        if code in COURSE_SKILL_MAP:
            skills.extend(COURSE_SKILL_MAP[code])

        # fallback mapping from curriculum
        if code in CURRICULUM_MAP:
            skills.append(CURRICULUM_MAP[code])

    return list(set(skills))


from openai import OpenAI

client = OpenAI(
    api_key=OPENAI_API_KEY,
    base_url="https://models.inference.ai.azure.com"  
)



def format_papers_for_prompt(papers: list) -> str:
    if not papers:
        return "No recent papers found."
    lines = []
    # Increased from 8 to 20
    for i, p in enumerate(papers[:20], 1):
        lines.append(f"{i}. [{p['domain']}] {p['topic']} — {p['url']}")
        if p.get("summary"):
            lines.append(f"   Abstract: {p['summary']}")
    return "\n".join(lines)


def generate_thesis_ideas(interests: list, skills: list, papers: list) -> list:
    papers_text = format_papers_for_prompt(papers)

    prompt = f"""You are an expert academic research advisor helping an undergraduate student find a thesis topic.

Student profile:
- Research interests: {", ".join(interests) if interests else "General AI/CS"}
- Skills from completed courses: {", ".join(skills) if skills else "Programming fundamentals"}

Recent trending research for inspiration (do NOT copy these — use them only as context):
{papers_text}

Generate exactly 5 unique, original thesis ideas tailored to this student's profile.

Rules:
- Ideas must be feasible for a 1-year undergraduate thesis
- Each idea must combine the student's interests AND skills
- Titles must be specific, not generic
- Methodology must be concrete and actionable
- related_research MUST contain exactly 3 papers from the list above
- related_papers MUST contain the matching URLs for those 3 papers in the same order

Return ONLY a valid JSON array, no markdown, no extra text:
[
  {{
    "title": "...",
    "description": "...",
    "methodology": "...",
    "tools": ["...", "..."],
    "difficulty": "Low|Medium|High",
    "related_research": ["paper title 1", "paper title 2", "paper title 3"],
    "paper_urls": ["url1", "url2", "url3"]
  }}
]"""

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": "You are an academic thesis advisor. Always respond with valid JSON only."},
            {"role": "user", "content": prompt}
        ],
        temperature=0.8,
        max_tokens=3000  # increased from 2000 to fit more content
    )

    raw = response.choices[0].message.content.strip()
    raw = re.sub(r"^```(?:json)?\s*", "", raw)
    raw = re.sub(r"\s*```$", "", raw)

    ideas = json.loads(raw)

    # Re-attach real URLs from ArXiv by matching titles
    paper_url_map = {p["topic"]: p["url"] for p in papers}
    for idea in ideas:
        idea["paper_urls"] = [
            paper_url_map.get(title, "")
            for title in idea.get("related_research", [])
        ]

    return ideas

@app.get("/api/generate_thesis/{user_id}")
def generate_thesis(user_id: str):
    db = cursor = None
    try:
        db = get_db()
        cursor = db.cursor(dictionary=True)

        # 1. Fetch interests
        cursor.execute(
            "SELECT interest_tag FROM user_interests WHERE user_id = %s",
            (user_id,)
        )
        interests = [row["interest_tag"] for row in cursor.fetchall()]

        # 2. Fetch completed courses and extract skills
        cursor.execute(
            "SELECT course_code FROM course_outlines WHERE user_id = %s AND status = 'Completed'",
            (user_id,)
        )
        courses_raw = cursor.fetchall()
        skills = extract_skills(courses_raw)

        # 3. Fetch trending ArXiv papers based on interests
        papers = fetch_real_research_from_arxiv(interests or ["Artificial Intelligence"])
        
        if not isinstance(papers, list):
            papers = []

        # 4. Generate ideas via AI (the actual call, finally!)
        ideas = generate_thesis_ideas(interests, skills, papers)

        return {"success": True, "ideas": ideas}

    except json.JSONDecodeError as e:
        return {"success": False, "error": f"AI returned invalid JSON: {str(e)}"}
    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        if cursor: cursor.close()
        if db: db.close()
