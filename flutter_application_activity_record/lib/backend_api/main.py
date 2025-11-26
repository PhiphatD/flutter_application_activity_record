from fastapi import FastAPI, HTTPException, Depends, File, UploadFile, Form, WebSocket, WebSocketDisconnect, Query
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session
from pydantic import BaseModel
from passlib.context import CryptContext
from datetime import date, datetime, time, timedelta
import models
from database import engine, get_db, SessionLocal
import random
import string
import smtplib 
from email.mime.text import MIMEText 
from email.mime.multipart import MIMEMultipart 
import csv
import codecs
import json
import os
import shutil
import threading
import time as time_module
import schedule
from contextlib import asynccontextmanager
from apscheduler.schedulers.asyncio import AsyncIOScheduler


# [SETUP] Create static folder if not exists
if not os.path.exists("static"):
    os.makedirs("static")

# สร้างตารางใน DB อัตโนมัติ (ถ้ายังไม่มี)
models.Base.metadata.create_all(bind=engine)

# Mount static files
app = FastAPI()
app.mount("/static", StaticFiles(directory="static"), name="static")

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# --- Schemas (ตัวกำหนดรูปแบบข้อมูลที่รับส่ง) ---

class AnnouncementRequest(BaseModel):
    title: str
    message: str
    target_role: str = "All"

class UpdateRedeemStatusRequest(BaseModel):
    status: str
    voucher_code: str | None = None # [NEW] รับโค้ดมาด้วย

class EmployeeUpdateRequest(BaseModel):
    title: str
    name: str
    phone: str
    email: str
    department_id: str # รับเป็น ID หรือ Name ก็ได้ (ในที่นี้ใช้ Logic resolve_department)
    position: str
    role: str
    status: str
    start_date: str # YYYY-MM-DD

class PointPolicyRequest(BaseModel):
    policy_name: str = "Annual Expiry Policy"
    start_date: date
    end_date: date
    description: str | None = None

# [UPDATED] รองรับรูปภาพหลายรูป (List)
class PrizeCreateRequest(BaseModel):
    name: str
    point_cost: int
    description: str | None = None
    images: list[str] = [] 
    stock: int
    prize_type: str = "Physical"
    pickup_instruction: str | None = "Contact HR"

class PrizePickupRequest(BaseModel):
    redeem_id: str
    admin_id: str

# [UPDATED] รองรับรูปภาพหลายรูป (List)
class PrizeResponse(BaseModel):
    id: str
    name: str
    pointCost: int
    description: str
    images: list[str] = [] # ใช้ List แทน String
    stock: int
    category: str = "General"
    status: str
    prizeType: str = "Physical"
    
    class Config:
        from_attributes = True

# 1. เพิ่ม Schema นี้ต่อจาก EmployeeUpdateRequest
class EmployeeCreateRequest(BaseModel):
    title: str
    name: str
    phone: str
    email: str
    department_id: str
    position: str
    role: str
    status: str = "Active"
    start_date: str
    password: str = "123456" # Default Password

# [UPDATED] รองรับรูปภาพหลายรูป (List)
class MyRedemptionResponse(BaseModel):
    redeemId: str
    prizeName: str
    pointCost: int
    redeemDate: datetime
    status: str
    images: list[str] = [] # ใช้ List แทน String
    pickupInstruction: str | None = "Contact HR"
    
    class Config:
        from_attributes = True



class CancelRedeemRequest(BaseModel):
    emp_id: str
    redeem_id: str

class RedeemRequest(BaseModel):
    emp_id: str
    prize_id: str

class ActivityRegisterRequest(BaseModel):
    emp_id: str
    session_id: str

class UnregisterRequest(BaseModel):
    emp_id: str
    session_id: str

class ForgotPasswordRequest(BaseModel):
    email: str

class ToggleFavoriteRequest(BaseModel):
    emp_id: str
    act_id: str

class VerifyOtpRequest(BaseModel):
    email: str
    otp: str

class ResetPasswordRequest(BaseModel):
    email: str
    newPassword: str

class LoginRequest(BaseModel):
    email: str
    password: str

class RegisterRequest(BaseModel):
    # Company Info
    companyName: str
    taxId: str
    address: str
    businessType: str
    
    # Admin Info
    adminTitle: str
    adminFullName: str
    adminEmail: str
    adminPhone: str
    adminPassword: str
    adminStartDate: str

class ActivityResponse(BaseModel):
    actId: str
    orgId: str
    organizerName: str
    actType: str
    isCompulsory: int
    point: int
    name: str
    currentParticipants: int
    maxParticipants: int
    status: str
    location: str = "-"
    activityDate: date | None = None
    startTime: str | None = "-" 
    endTime: str | None = "-"
    isRegistered: bool = False
    class Config:
        orm_mode = True

class ActivitySessionResponse(BaseModel):
    sessionId: str
    date: date
    startTime: time
    endTime: time
    location: str
    status: str
    class Config:
        orm_mode = True

class ActivityDetailResponse(BaseModel):
    actId: str
    orgId: str
    organizerName: str
    organizerContact: str 
    depName: str          
    actType: str
    name: str
    description: str      
    isCompulsory: int
    point: int
    cost: float           
    condition: str        
    status: str
    maxParticipants: int
    currentParticipants: int
    eventHost: str        
    guestSpeaker: str     
    foodInfo: str         
    travelInfo: str       
    moreDetails: str      
    targetCriteria: str | None = None
    actAttachments: str | None = "[]"
    agenda: str | None = None
    isFavorite: bool = False
    isRegistered: bool = False
    sessions: list[ActivitySessionResponse]

    class Config:
        orm_mode = True

class ActivityAttachmentRequest(BaseModel):
    url: str
    type: str = "IMAGE"
    name: str = "image.jpg"

class ActivityData(BaseModel):
    ACT_NAME: str
    ACT_TYPE: str
    ACT_DESCRIPTIONS: str | None = None
    ACT_POINT: int
    ACT_GUEST_SPEAKER: str | None = None
    ACT_EVENT_HOST: str | None = None
    ACT_MAX_PARTICIPANTS: int
    DEP_ID: str
    ACT_COST: float
    ACT_TRAVEL_INFO: str | None = None
    ACT_FOOD_INFO: str | None = None
    ACT_MORE_DETAILS: str | None = None
    ACT_PARTICIPATION_CONDITION: str | None = None
    ACT_ISCOMPULSORY: int
    ACT_STATUS: str = "Open"
    ACT_TARGET_CRITERIA: str | None = None
    # [NEW] รับเป็น List แทน
    ACT_ATTACHMENTS: list[ActivityAttachmentRequest] = [] 
    # ACT_IMAGE: str | None = None <-- (เลิกใช้)
    ACT_AGENDA: str | None = None

class OrganizerData(BaseModel):
    ORG_NAME: str
    ORG_CONTACT_INFO: str

class SessionData(BaseModel):
    SESSION_DATE: str
    START_TIME: str
    END_TIME: str
    LOCATION: str

class ActivityFormRequest(BaseModel):
    ACTIVITY: ActivityData
    ORGANIZER: OrganizerData
    SESSIONS: list[SessionData]

class MyActivityResponse(BaseModel):
    actId: str
    actType: str
    name: str
    location: str
    activityDate: date
    startTime: str
    endTime: str
    status: str
    sessionId: str
    isCompulsory: bool
    point: int

    class Config:
        from_attributes = True

class NotificationResponse(BaseModel):
    notifId: str
    title: str
    message: str
    type: str        # Activity, Reward, Alert
    isRead: bool
    createdAt: datetime
    routePath: str | None = None
    refId: str | None = None

    class Config:
        from_attributes = True

class CreateNotificationRequest(BaseModel):
    emp_id: str
    title: str
    message: str
    type: str
    ref_id: str | None = None
    route_path: str | None = None

class ConnectionManager:
    def __init__(self):
        # เปลี่ยนจาก list เป็น dict เพื่อเก็บ emp_id -> websocket
        self.active_connections: dict[str, WebSocket] = {} 

    async def connect(self, websocket: WebSocket, emp_id: str):
        await websocket.accept()
        self.active_connections[emp_id] = websocket

    def disconnect(self, emp_id: str):
        if emp_id in self.active_connections:
            del self.active_connections[emp_id]

    async def send_personal_message(self, message: str, emp_id: str):
        # ส่งหาเฉพาะคน
        if emp_id in self.active_connections:
            await self.active_connections[emp_id].send_text(message)
            
    async def broadcast(self, message: str):
        # ส่งหาทุกคน (สำหรับ Admin ประกาศ)
        for connection in self.active_connections.values():
            await connection.send_text(message)

manager = ConnectionManager()

class ParticipantResponse(BaseModel):
    empId: str
    title: str | None = None 
    name: str
    department: str
    status: str
    checkInTime: str
    
    class Config:
        orm_mode = True

class CheckInRequest(BaseModel):
    emp_id: str
    act_id: str
    scanned_by: str
    location_lat: float | None = None
    location_long: float | None = None

class TargetCountRequest(BaseModel):
    type: str = "all"
    departments: list[str] = []
    positions: list[str] = []
    admin_id: str | None = None


    
# --- Helper Functions ---

async def check_upcoming_notifications():
    """ รันทุก 1 นาที เพื่อเช็คการแจ้งเตือนระยะสั้น (1 ชม.) """
    print("⏱️ Running Upcoming Check...")
    db = SessionLocal()
    try:
        now = datetime.now()
        target_time_start = now + timedelta(minutes=59)
        target_time_end = now + timedelta(minutes=61)

        upcoming_sessions = db.query(models.ActivitySession).all()
        
        count_sent = 0
        for sess in upcoming_sessions:
            sess_start_dt = datetime.combine(sess.SESSION_DATE, sess.START_TIME)
            
            if target_time_start <= sess_start_dt <= target_time_end:
                regs = db.query(models.Registration).filter(
                    models.Registration.SESSION_ID == sess.SESSION_ID
                ).all()
                
                act = sess.activity
                for reg in regs:
                    # 1. สร้าง Notif ลง DB
                    create_notification_internal(
                        db,
                        emp_id=reg.EMP_ID,
                        title="⏳ อีก 1 ชั่วโมงกิจกรรมจะเริ่ม",
                        message=f"เตรียมตัวให้พร้อม! '{act.ACT_NAME}' จะเริ่มเวลา {sess.START_TIME.strftime('%H:%M')} น.",
                        notif_type="Activity",
                        ref_id=act.ACT_ID,
                        route_path="/activity_detail"
                    )
                    # 2. [NEW] ยิง Socket หาพนักงานคนนั้นทันที!
                    await manager.send_personal_message("REFRESH_NOTIFICATIONS", reg.EMP_ID)
                    count_sent += 1
                    
        db.commit()
        if count_sent > 0:
            print(f"✅ Sent upcoming reminders to {count_sent} users.")
            
    except Exception as e:
        print(f"❌ Hourly Check Error: {e}")
        db.rollback()
    finally:
        db.close()

def check_is_target(activity, employee):
    """
    ฟังก์ชันตรวจสอบว่าพนักงานตรงกับ Target Criteria ของกิจกรรมหรือไม่
    """
    # 1. ถ้าไม่มี Criteria หรือเป็น NULL -> ถือว่าบังคับทุกคน
    if not activity.ACT_TARGET_CRITERIA:
        return True
        
    try:
        criteria = json.loads(activity.ACT_TARGET_CRITERIA)
        target_type = criteria.get('type', 'all')
        
        if target_type == 'all':
            return True
            
        if target_type == 'specific':
            # เตรียมข้อมูลพนักงาน (ตัดช่องว่าง)
            emp_dept = employee.department.DEP_NAME.strip() if employee.department else ""
            emp_pos = employee.EMP_POSITION.strip()
            
            # เตรียมข้อมูล Target (ตัดช่องว่าง)
            target_depts = [d.strip() for d in criteria.get('departments', [])]
            target_positions = [p.strip() for p in criteria.get('positions', [])]
            
            # เทียบเงื่อนไข (แผนกตรง หรือ ตำแหน่งตรง)
            if target_depts and emp_dept in target_depts:
                return True
            if target_positions and emp_pos in target_positions:
                return True
                
            return False # เป็นแบบ Specific แต่ไม่ตรงเงื่อนไขใดเลย
            
        return True # Type อื่นๆ ให้ผ่านไว้ก่อน (Fail-safe)
        
    except Exception as e:
        print(f"Target check error: {e}")
        return True # ถ้า JSON พัง ให้ยอมรับไว้ก่อน (Fail-safe)
def get_admin_company_id_and_check(admin_id: str, db: Session):
    admin = db.query(models.Employee).filter(models.Employee.EMP_ID == admin_id).first()
    
    if not admin or admin.EMP_ROLE.lower() != 'admin':
        raise HTTPException(status_code=403, detail="Permission denied. Must be Admin.")
        
    return admin.COMPANY_ID

def _bcrypt_safe(password: str) -> str:
    pw_bytes = password.encode('utf-8') if isinstance(password, str) else password
    pw_bytes = pw_bytes[:72]
    return pw_bytes.decode('utf-8', errors='ignore')

def get_password_hash(password):
    return pwd_context.hash(_bcrypt_safe(password))

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(_bcrypt_safe(plain_password), hashed_password)

def generate_id(prefix, length=5):
    return prefix + ''.join(random.choices(string.digits, k=length-1))




@asynccontextmanager
async def lifespan(app: FastAPI):
    # 1. สร้าง Scheduler
    scheduler = AsyncIOScheduler()
    
    # 2. ตั้งเวลา (Cron Job / Interval)
    # รันทุกๆ 1 นาที (เพื่อเทส) หรือตามต้องการ
    scheduler.add_job(check_upcoming_notifications, 'interval', minutes=1)
    
    # รันทุกวันตอน 8 โมงเช้า
    scheduler.add_job(check_daily_notifications, 'cron', hour=8, minute=0)
    
    # 3. เริ่มทำงาน
    scheduler.start()
    print("🚀 Scheduler Started (AsyncIO Mode)")
    
    yield # รัน Server ต่อไป...
    
    # 4. (Optional) ตอนปิด Server
    # scheduler.shutdown()

# [APPLY] ผูก Lifespan เข้ากับ App
app = FastAPI(lifespan=lifespan)
app.mount("/static", StaticFiles(directory="static"), name="static")


async def check_daily_notifications():
    """ รันทุกวัน 08:00 เพื่อแจ้งเตือนล่วงหน้า 1 วัน และแต้มหมดอายุ """
    print("⏰ Running Daily Check...")
    db = SessionLocal()
    try:
        today = date.today()
        tomorrow = today + timedelta(days=1)
        yesterday = today - timedelta(days=1)

        # ... (Logic เดิม: เตือน Employee กิจกรรมพรุ่งนี้ / แต้มหมดอายุ) ...

        # --- [NEW] Organizer: Low Registration Alert (เตือนกิจกรรมพรุ่งนี้ที่คนน้อย) ---
        upcoming_acts = db.query(models.Activity).join(models.ActivitySession).filter(
            models.ActivitySession.SESSION_DATE == tomorrow,
            models.Activity.ACT_STATUS == 'Open'
        ).distinct().all()

        for act in upcoming_acts:
            # ถ้าคนลงทะเบียนน้อยกว่า 50%
            current = db.query(models.Registration).join(models.ActivitySession).filter(
                models.ActivitySession.ACT_ID == act.ACT_ID
            ).count()
            
            max_p = act.ACT_MAX_PARTICIPANTS
            if max_p > 0 and (current / max_p) < 0.5:
                org_emp_id = act.organizer.EMP_ID if act.organizer else None
                if org_emp_id:
                     create_notification_internal(
                        db,
                        emp_id=org_emp_id,
                        title="⚠️ ยอดลงทะเบียนน้อยกว่าเกณฑ์",
                        message=f"กิจกรรม '{act.ACT_NAME}' เริ่มพรุ่งนี้ แต่มีคนลงทะเบียนเพียง {current}/{max_p} คน โปรดเร่งประชาสัมพันธ์",
                        notif_type="Alert",
                        target_role="Organizer",
                        ref_id=act.ACT_ID,
                        route_path="/manage"
                    )
                     await manager.send_personal_message("REFRESH_NOTIFICATIONS", org_emp_id)

        # --- [NEW] Organizer: Event Day Summary (สรุปกิจกรรมเมื่อวาน) ---
        ended_acts = db.query(models.Activity).join(models.ActivitySession).filter(
            models.ActivitySession.SESSION_DATE == yesterday
        ).distinct().all()

        for act in ended_acts:
            # นับยอด Register vs Check-in
            sessions = db.query(models.ActivitySession).filter(models.ActivitySession.ACT_ID == act.ACT_ID).all()
            sess_ids = [s.SESSION_ID for s in sessions]
            
            reg_count = db.query(models.Registration).filter(models.Registration.SESSION_ID.in_(sess_ids)).count()
            checkin_count = db.query(models.CheckIn).filter(models.CheckIn.SESSION_ID.in_(sess_ids)).count()

            org_emp_id = act.organizer.EMP_ID if act.organizer else None
            if org_emp_id:
                create_notification_internal(
                    db,
                    emp_id=org_emp_id,
                    title="📊 สรุปผลกิจกรรม",
                    message=f"กิจกรรม '{act.ACT_NAME}' จบแล้ว\nลงทะเบียน: {reg_count} | เช็คอิน: {checkin_count} คน",
                    notif_type="System",
                    target_role="Organizer",
                    ref_id=act.ACT_ID,
                    route_path="/participants"
                )
                await manager.send_personal_message("REFRESH_NOTIFICATIONS", org_emp_id)

        # --- ส่วนที่ 1: เตือนกิจกรรมพรุ่งนี้ ---
        upcoming_sessions = db.query(models.ActivitySession).filter(
            models.ActivitySession.SESSION_DATE == tomorrow
        ).all()

        for sess in upcoming_sessions:
            regs = db.query(models.Registration).filter(
                models.Registration.SESSION_ID == sess.SESSION_ID
            ).all()
            
            act = sess.activity
            for reg in regs:
                create_notification_internal(
                    db,
                    emp_id=reg.EMP_ID,
                    title="🔔 กิจกรรมจะเริ่มพรุ่งนี้",
                    message=f"อย่าลืม! กิจกรรม '{act.ACT_NAME}' จะเริ่มเวลา {sess.START_TIME.strftime('%H:%M')}",
                    notif_type="Activity",
                    ref_id=act.ACT_ID,
                    route_path="/activity_detail"
                )
                # [NEW] ยิง Socket
                await manager.send_personal_message("REFRESH_NOTIFICATIONS", reg.EMP_ID)

        # --- ส่วนที่ 2: เตือนแต้มหมดอายุ ---
        # สมมติ Policy ตัดทุกสิ้นปี
        this_year_end = date(today.year, 12, 31)
        days_left = (this_year_end - today).days
        
        if days_left == 30 or days_left == 7: # เตือนเมื่อเหลือ 30 วัน และ 7 วัน
            users_with_points = db.query(models.Points).filter(models.Points.TOTAL_POINTS > 0).all()
            for user_p in users_with_points:
                create_notification_internal(
                    db,
                    emp_id=user_p.EMP_ID,
                    title="⚠️ คะแนนใกล้หมดอายุ",
                    message=f"คุณมี {user_p.TOTAL_POINTS} คะแนนที่จะหมดอายุในอีก {days_left} วัน รีบใช้เลย!",
                    notif_type="Alert",
                    target_role="Employee",
                    route_path="/rewards"
                )

        db.commit()
        print("✅ Daily Check Complete")
        
    except Exception as e:
        print(f"❌ Daily Check Error: {e}")
        db.rollback()
    finally:
        db.close()

def create_notification_internal(
    db: Session, 
    emp_id: str, 
    title: str, 
    message: str, 
    notif_type: str, 
    target_role: str = "Employee",
    ref_id: str = None, 
    route_path: str = None
    
):
    """
    ฟังก์ชันกลางสำหรับสร้าง Notification ลง DB และส่ง WebSocket (ถ้าทำได้)
    """
    try:
        # 1. สร้าง ID ใหม่ (เช่น NT + timestamp + random)
        new_id = generate_id("NT", 12) 
        
        # 2. สร้าง Object
        new_notif = models.Notification(
            NOTIF_ID=new_id,
            EMP_ID=emp_id,
            TITLE=title,
            MESSAGE=message,
            NOTIF_TYPE=notif_type,
            TARGET_ROLE=target_role,
            REF_ID=ref_id,
            ROUTE_PATH=route_path,
            IS_READ=False,
            CREATED_AT=datetime.now()
        )
        db.add(new_notif)
        # หมายเหตุ: เราจะไม่ db.commit() ที่นี่ เพื่อให้มัน commit พร้อม transaction หลักได้
        # แต่ถ้าต้องการให้แจ้งเตือนแยกส่วน ก็ db.commit() ได้เลย
        # ในที่นี้ขอให้ Caller เป็นคน Commit เพื่อความปลอดภัยของ Transaction
        
        print(f"🔔 Notification created for {emp_id}: {title}")
        return new_notif
        
    except Exception as e:
        print(f"Error creating notification: {e}")

def send_otp_email(to_email: str, otp_code: str):
    sender_email = "nut98765431@gmail.com"
    sender_password = "vamo wowf mbzm lkkz"

    subject = "รหัส OTP สำหรับรีเซ็ตรหัสผ่าน - Activity App"
    body = f"""
    สวัสดี,
    
    คุณได้ทำการร้องขอรหัสผ่านใหม่
    รหัส OTP ของคุณคือ: {otp_code}
    
    หากคุณไม่ได้ทำรายการนี้ โปรดเพิกเฉยต่ออีเมลฉบับนี้
    """

    msg = MIMEMultipart()
    msg['From'] = sender_email
    msg['To'] = to_email
    msg['Subject'] = subject
    msg.attach(MIMEText(body, 'plain'))

    try:
        server = smtplib.SMTP('smtp.gmail.com', 587)
        server.starttls()
        server.login(sender_email, sender_password)
        text = msg.as_string()
        server.sendmail(sender_email, to_email, text)
        server.quit()
        print(f"✅ Email sent to {to_email}")
    except Exception as e:
        print(f"❌ Failed to send email: {e}")
        raise Exception("ไม่สามารถส่งอีเมลได้ กรุณาตรวจสอบระบบ")

def parse_date_str(date_str: str) -> date:
    if not date_str or not date_str.strip():
        return date.today()
    
    d = date_str.strip()
    formats = ['%Y-%m-%d', '%d/%m/%Y', '%d-%m-%Y', '%Y/%m/%d']
    for fmt in formats:
        try:
            return datetime.strptime(d, fmt).date()
        except ValueError:
            continue
    return date.today()

def parse_time_safe(t_str: str) -> time:
    if not t_str:
        return time(9, 0)
    t_str = t_str.strip()
    formats = ["%H:%M", "%H:%M:%S", "%I:%M %p"] 
    for fmt in formats:
        try:
            return datetime.strptime(t_str, fmt).time()
        except ValueError:
            continue
    return time(9, 0)

# --- API Endpoints ---

@app.post("/login")
def login(req: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(models.Employee).filter(models.Employee.EMP_EMAIL == req.email).first()
    
    if not user or not verify_password(req.password, user.EMP_PASSWORD):
        raise HTTPException(status_code=400, detail="อีเมลหรือรหัสผ่านไม่ถูกต้อง")
    
    org_id = None
    if user.organizer_profile:
        org_id = user.organizer_profile.ORG_ID

    return {
        "message": "Login successful",
        "role": user.EMP_ROLE,
        "emp_id": user.EMP_ID,
        "company_id": user.COMPANY_ID,
        "name": user.EMP_NAME_EN,
        "org_id": org_id
    }

@app.post("/register_organization")
def register_org(req: RegisterRequest, db: Session = Depends(get_db)):
    existing_user = db.query(models.Employee).filter(models.Employee.EMP_EMAIL == req.adminEmail).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="อีเมลนี้ถูกใช้งานแล้ว")

    try:
        new_company_id = generate_id("C")
        while db.query(models.Company).filter(models.Company.COMPANY_ID == new_company_id).first():
             new_company_id = generate_id("C")

        new_company = models.Company(
            COMPANY_ID=new_company_id,
            COMPANY_NAME=req.companyName,
            TAX_ID=req.taxId,
            ADDRESS=req.address,
            BUSINESS_TYPE=req.businessType
        )
        db.add(new_company)

        new_dep_id = generate_id("D")
        while db.query(models.Department).filter(models.Department.DEP_ID == new_dep_id).first():
             new_dep_id = generate_id("D")

        new_department = models.Department(
            DEP_ID=new_dep_id,
            COMPANY_ID=new_company_id,
            DEP_NAME="Headquarters"
        )
        db.add(new_department)

        new_emp_id = generate_id("E")
        while db.query(models.Employee).filter(models.Employee.EMP_ID == new_emp_id).first():
            new_emp_id = generate_id("E")

        hashed_pw = get_password_hash(req.adminPassword)
        try:
            start_date_obj = date.fromisoformat(req.adminStartDate)
        except (ValueError, TypeError):
            start_date_obj = date.today()

        new_admin = models.Employee(
            EMP_ID=new_emp_id,
            COMPANY_ID=new_company_id,
            EMP_TITLE_EN=req.adminTitle,
            EMP_NAME_EN=req.adminFullName,
            EMP_POSITION="Administrator",
            DEP_ID=new_dep_id,
            EMP_PHONE=req.adminPhone,
            EMP_EMAIL=req.adminEmail,
            EMP_PASSWORD=hashed_pw,
            EMP_STARTDATE=start_date_obj,
            EMP_STATUS="Active",
            EMP_ROLE="admin"
        )
        db.add(new_admin)
        db.commit()
        
        return {
            "message": "ลงทะเบียนองค์กรสำเร็จ", 
            "emp_id": new_emp_id,
            "company_id": new_company_id
        }

    except Exception as e:
        db.rollback()
        print(f"Error Registering: {e}")
        raise HTTPException(status_code=500, detail=f"เกิดข้อผิดพลาด: {str(e)}")
    
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)


@app.post("/debug/fire-test")
async def fire_test_notification(emp_id: str):
    print(f"🔫 Pow! Firing test notification to {emp_id}...")
    # ยิงสัญญาณเข้าเครื่อง Employee คนนั้นทันที
    await manager.send_personal_message("REFRESH_NOTIFICATIONS", emp_id)
    return {"status": "Fired!"}


@app.post("/forgot-password")
def forgot_password(req: ForgotPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(models.Employee).filter(models.Employee.EMP_EMAIL == req.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="ไม่พบอีเมลนี้ในระบบ")
    
    otp = ''.join(random.choices(string.digits, k=6))
    user.OTP_CODE = otp
    db.commit()
    
    try:
        send_otp_email(req.email, otp)
    except Exception as e:
        raise HTTPException(status_code=500, detail="เกิดข้อผิดพลาดในการส่งอีเมล")
    
    return {"message": "ส่งรหัส OTP ไปยังอีเมลเรียบร้อยแล้ว"}

@app.post("/verify-otp")
def verify_otp(req: VerifyOtpRequest, db: Session = Depends(get_db)):
    user = db.query(models.Employee).filter(models.Employee.EMP_EMAIL == req.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    if user.OTP_CODE != req.otp:
        raise HTTPException(status_code=400, detail="รหัส OTP ไม่ถูกต้อง")
        
    return {"message": "OTP ถูกต้อง"}

@app.post("/reset-password")
def reset_password(req: ResetPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(models.Employee).filter(models.Employee.EMP_EMAIL == req.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    hashed_pw = get_password_hash(req.newPassword)
    user.EMP_PASSWORD = hashed_pw
    user.OTP_CODE = None
    db.commit()
    
    return {"message": "เปลี่ยนรหัสผ่านสำเร็จ"}

@app.get("/employees/{emp_id}")
def get_employee_profile(emp_id: str, db: Session = Depends(get_db)):
    user = db.query(models.Employee).filter(models.Employee.EMP_ID == emp_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="ไม่พบข้อมูลพนักงาน")
    
    dep_name = "-"
    if user.department:
        dep_name = user.department.DEP_NAME

    comp_name = "-"
    if user.company:
        comp_name = user.company.COMPANY_NAME

    current_points = 0
    # [NEW] เพิ่มตัวแปรสำหรับวันหมดอายุ
    expiry_date = None

    if user.points:
        current_points = user.points.TOTAL_POINTS
        # [NEW LOGIC] ดึง EXPIRY_DATE และแปลงเป็น ISO String
        if user.points.EXPIRY_DATE:
            expiry_date = user.points.EXPIRY_DATE.isoformat() 

    return {
        "EMP_ID": user.EMP_ID,
        "EMP_TITLE_EN": user.EMP_TITLE_EN,
        "EMP_NAME_EN": user.EMP_NAME_EN,
        "EMP_POSITION": user.EMP_POSITION,
        "DEP_NAME": dep_name,
        "COMPANY_NAME": comp_name,
        "EMP_EMAIL": user.EMP_EMAIL,
        "EMP_PHONE": user.EMP_PHONE,
        "EMP_STARTDATE": user.EMP_STARTDATE,
        "TOTAL_POINTS": current_points,
        "EXPIRY_DATE": expiry_date # <-- ส่งค่านี้ออกไป
    }

@app.post("/admin/import_employees") 
async def import_employees(
    admin_id: str = Form(...),      
    file: UploadFile = File(...),   
    db: Session = Depends(get_db)
):
    admin_user = db.query(models.Employee).filter(models.Employee.EMP_ID == admin_id).first()
    if not admin_user:
        raise HTTPException(status_code=404, detail="Admin not found")
    
    current_company_id = admin_user.COMPANY_ID
    print(f"📥 Importing for Company ID: {current_company_id}")

    try:
        csvReader = csv.DictReader(codecs.iterdecode(file.file, 'utf-8-sig'))
        success_count = 0
        errors = []

        for row in csvReader:
            try:
                dep_name = row.get('Department', 'General').strip()
                department = db.query(models.Department).filter(
                    models.Department.DEP_NAME == dep_name,
                    models.Department.COMPANY_ID == current_company_id 
                ).first()

                if not department:
                    new_dep_id = generate_id("D")
                    while db.query(models.Department).filter(models.Department.DEP_ID == new_dep_id).first():
                         new_dep_id = generate_id("D")
                    
                    department = models.Department(
                        DEP_ID=new_dep_id,
                        COMPANY_ID=current_company_id,
                        DEP_NAME=dep_name
                    )
                    db.add(department)
                    db.commit() 
                    db.refresh(department)

                email = row.get('Email', '').strip()
                if db.query(models.Employee).filter(models.Employee.EMP_EMAIL == email).first():
                    errors.append(f"Email {email} already exists.")
                    continue

                raw_role = row.get('Role', 'employee').strip().lower()
                final_role = 'employee'
                if raw_role in ['organizer', 'organiser', 'admin']:
                    final_role = 'organizer' if raw_role != 'admin' else 'admin'

                start_date_val = parse_date_str(row.get('StartDate', ''))

                new_emp_id = generate_id("E")
                while db.query(models.Employee).filter(models.Employee.EMP_ID == new_emp_id).first():
                    new_emp_id = generate_id("E")

                new_emp = models.Employee(
                    EMP_ID=new_emp_id,
                    COMPANY_ID=current_company_id, 
                    EMP_TITLE_EN=row.get('Title', ''),
                    EMP_NAME_EN=row.get('Name', ''), 
                    EMP_POSITION=row.get('Position', 'Staff'),
                    DEP_ID=department.DEP_ID,          
                    EMP_PHONE=row.get('Phone', ''),
                    EMP_EMAIL=email,
                    EMP_PASSWORD=get_password_hash(row.get('Password', '123456')),
                    EMP_STARTDATE=start_date_val,
                    EMP_STATUS='Active',
                    EMP_ROLE=final_role,
                    OTP_CODE=None
                )
                db.add(new_emp)

                if final_role == 'organizer':
                    new_org_id = generate_id("O") 
                    new_org = models.Organizer(
                        ORG_ID=new_org_id,
                        EMP_ID=new_emp_id,
                        ORG_CONTACT_INFO=new_emp.EMP_PHONE, 
                        ORG_UNIT=department.DEP_NAME,       
                        ORG_NOTE="Imported via CSV"
                    )
                    db.add(new_org)

                db.commit()
                success_count += 1

            except Exception as row_error:
                db.rollback()
                errors.append(f"Error processing row {row.get('Name', '?')}: {str(row_error)}")
                continue

        return {
            "message": "Import process completed",
            "success_count": success_count,
            "errors": errors
        }

    except Exception as e:
        return {"message": "Failed to read CSV file", "error": str(e)}

@app.get("/activities", response_model=list[ActivityResponse])
def get_activities(mode: str = "all", emp_id: str | None = None, db: Session = Depends(get_db)):
    today = date.today()
    now = datetime.now()

    requester = None
    req_dept = ""
    req_pos = ""
    
    if emp_id:
        requester = db.query(models.Employee).filter(models.Employee.EMP_ID == emp_id).first()
        if requester:
            req_dept = requester.department.DEP_NAME if requester.department else ""
            req_pos = requester.EMP_POSITION

    all_employees = db.query(models.Employee).filter(models.Employee.EMP_STATUS == 'Active').all()
    emp_data_list = []
    for emp in all_employees:
        emp_data_list.append({
            "dept_name": emp.department.DEP_NAME if emp.department else "",
            "position": emp.EMP_POSITION
        })

    query = db.query(models.Activity).join(models.ActivitySession)
    if mode == "future":
        # [FIX] ดึงย้อนหลัง 1 วัน เผื่อมีกิจกรรมข้ามคืนที่ยังไม่จบ
        yesterday = today - timedelta(days=1)
        query = query.filter(models.ActivitySession.SESSION_DATE >= yesterday)
        
    activities = query.distinct().all()
    
    registered_act_ids = set()
    if emp_id:
        user_regs = db.query(models.Registration).filter(models.Registration.EMP_ID == emp_id).all()
        for r in user_regs:
            sess = db.query(models.ActivitySession).filter(models.ActivitySession.SESSION_ID == r.SESSION_ID).first()
            if sess:
                registered_act_ids.add(sess.ACT_ID)
    
    results = []
    for act in activities:
        if act.ACT_ISCOMPULSORY and requester:
            if act.ACT_TARGET_CRITERIA:
                try:
                    criteria = json.loads(act.ACT_TARGET_CRITERIA)
                    target_type = criteria.get('type', 'all')
                    
                    if target_type == 'specific':
                        target_depts = criteria.get('departments', [])
                        target_positions = criteria.get('positions', [])
                        is_match = False
                        if req_dept in target_depts:
                            is_match = True
                        if not is_match and req_pos in target_positions:
                            is_match = True
                        if not is_match:
                            continue 
                except:
                    pass

        current_count = 0
        if act.ACT_ISCOMPULSORY:
            if not act.ACT_TARGET_CRITERIA:
                current_count = len(emp_data_list)
            else:
                try:
                    criteria = json.loads(act.ACT_TARGET_CRITERIA)
                    target_type = criteria.get('type', 'all')
                    if target_type == 'all':
                        current_count = len(emp_data_list)
                    elif target_type == 'specific':
                        target_depts = criteria.get('departments', [])
                        target_positions = criteria.get('positions', [])
                        count = 0
                        for emp in emp_data_list:
                            is_match = False
                            if emp["dept_name"] in target_depts:
                                is_match = True
                            if not is_match and emp["position"] in target_positions:
                                is_match = True
                            if is_match:
                                count += 1
                        current_count = count
                except:
                    current_count = len(emp_data_list)
        else:
            current_count = db.query(models.Registration)\
                .join(models.ActivitySession, models.Registration.SESSION_ID == models.ActivitySession.SESSION_ID)\
                .filter(models.ActivitySession.ACT_ID == act.ACT_ID)\
                .count()
            
        location = "-"
        act_date = None
        start_time = "-"
        end_time = "-"

        if act.sessions and len(act.sessions) > 0:
            # เรียงตามเวลา
            sorted_sessions = sorted(act.sessions, key=lambda x: (x.SESSION_DATE, x.START_TIME))
            
            target_session = None

            if mode == "future":
                # [NEW LOGIC] หา Session ที่ "ยังไม่จบ" (End Time > Now)
                valid_sessions = []
                for s in sorted_sessions:
                    s_start_dt = datetime.combine(s.SESSION_DATE, s.START_TIME)
                    s_end_dt = datetime.combine(s.SESSION_DATE, s.END_TIME)
                    
                    # แก้บั๊กข้ามคืน (ถ้าจบตี 2 ของอีกวัน)
                    if s.END_TIME <= s.START_TIME:
                        s_end_dt += timedelta(days=1)
                    
                    # เงื่อนไข: กิจกรรมต้องยังไม่จบ (เวลาจบ ต้องอยู่หลังเวลาปัจจุบัน)
                    if s_end_dt > now:
                        valid_sessions.append(s)
                
                if valid_sessions:
                    target_session = valid_sessions[0] # เอาอันแรกที่ยังไม่จบ
                else:
                    continue # ถ้าจบหมดแล้ว ก็ข้ามไปเลย (ไม่แสดงใน Feed)
            else:
                target_session = sorted_sessions[0]

            start_time = target_session.START_TIME.strftime("%H:%M")
            end_time = target_session.END_TIME.strftime("%H:%M")
            location = f"{target_session.LOCATION}"
            act_date = target_session.SESSION_DATE
            
        org_name = "-"
        if act.organizer and act.organizer.employee:
            org_name = act.organizer.employee.EMP_NAME_EN
        
        is_reg = False
        if act.ACT_ID in registered_act_ids:
            is_reg = True
        
        results.append({
            "actId": act.ACT_ID,
            "orgId": act.ORG_ID,
            "organizerName": org_name,
            "actType": act.ACT_TYPE,
            "isCompulsory": 1 if act.ACT_ISCOMPULSORY else 0,
            "point": act.ACT_POINT,
            "name": act.ACT_NAME,
            "maxParticipants": act.ACT_MAX_PARTICIPANTS,
            "status": act.ACT_STATUS,
            "currentParticipants": current_count,
            "location": location,
            "activityDate": act_date, 
            "startTime": start_time, 
            "endTime": end_time,
            "isRegistered": is_reg
        })
        
    return results
@app.post("/activities/count-target")
def count_target_audience(req: TargetCountRequest, db: Session = Depends(get_db)):
    try:
        # 1. Find Company ID
        company_id = None
        if req.admin_id:
             admin = db.query(models.Employee).filter(models.Employee.EMP_ID == req.admin_id).first()
             if admin: company_id = admin.COMPANY_ID
        
        # 2. Query all active employees in company
        query = db.query(models.Employee).filter(models.Employee.EMP_STATUS == 'Active')
        if company_id:
            query = query.filter(models.Employee.COMPANY_ID == company_id)
            
        all_employees = query.all()
        
        # 3. Count based on criteria
        if req.type == 'all':
            return {"count": len(all_employees)}
            
        # Specific Group Logic
        count = 0
        target_depts = [d.strip() for d in req.departments]
        target_positions = [p.strip() for p in req.positions]
        
        for emp in all_employees:
            emp_dept = emp.department.DEP_NAME.strip() if emp.department else ""
            emp_pos = emp.EMP_POSITION.strip()
            
            is_match = False
            # Dept Match
            if target_depts and emp_dept in target_depts:
                is_match = True
            # Position Match
            elif target_positions and emp_pos in target_positions:
                is_match = True
                
            if is_match:
                count += 1
                
        return {"count": count}
        
    except Exception as e:
        print(f"Count Error: {e}")
        return {"count": 0}
        
@app.get("/activities/{act_id}", response_model=ActivityDetailResponse)
def get_activity_detail(
    act_id: str, 
    emp_id: str | None = None, 
    db: Session = Depends(get_db)
):
    act = db.query(models.Activity).filter(models.Activity.ACT_ID == act_id).first()
    if not act:
        raise HTTPException(status_code=404, detail="Activity not found")
    
    current_count = 0
    
    if act.ACT_ISCOMPULSORY:
        current_count = count_target_employees(db, act.ACT_TARGET_CRITERIA)
    else:
        current_count = db.query(models.Registration)\
            .join(models.ActivitySession, models.Registration.SESSION_ID == models.ActivitySession.SESSION_ID)\
            .filter(models.ActivitySession.ACT_ID == act.ACT_ID)\
            .count()

    is_fav = False
    if emp_id:
        fav = db.query(models.Favorite).filter(
            models.Favorite.EMP_ID == emp_id,
            models.Favorite.ACT_ID == act_id
        ).first()
        if fav: is_fav = True

    is_registered = False
    registered_session_id = None
    
    if emp_id:
        user_reg = db.query(models.Registration)\
            .join(models.ActivitySession)\
            .filter(
                models.Registration.EMP_ID == emp_id,
                models.ActivitySession.ACT_ID == act_id
            ).first()
            
        if user_reg:
            is_registered = True
            registered_session_id = user_reg.SESSION_ID

    org_name = "-"
    org_contact = "-"
    if act.organizer:
        org_contact = act.organizer.ORG_CONTACT_INFO
        if act.organizer.employee:
            org_name = act.organizer.employee.EMP_NAME_EN

    dep_name = "-"
    dep = db.query(models.Department).filter(models.Department.DEP_ID == act.DEP_ID).first()
    if dep:
        dep_name = dep.DEP_NAME

    sessions_data = []
    for s in act.sessions:
        sessions_data.append({
            "sessionId": s.SESSION_ID,
            "date": s.SESSION_DATE,
            "startTime": s.START_TIME,
            "endTime": s.END_TIME,
            "location": s.LOCATION,
            "status": s.SESSION_STATUS
        })

    return {
        "actId": act.ACT_ID,
        "orgId": act.ORG_ID,
        "organizerName": org_name,
        "organizerContact": org_contact,
        "depName": dep_name,
        "actType": act.ACT_TYPE,
        "name": act.ACT_NAME,
        "description": act.ACT_DESCRIPTIONS or "",
        "isCompulsory": 1 if act.ACT_ISCOMPULSORY else 0,
        "point": act.ACT_POINT,
        "cost": float(act.ACT_COST or 0.0),
        "condition": act.ACT_PARTICIPATION_CONDITION or "-",
        "status": act.ACT_STATUS,
        "maxParticipants": act.ACT_MAX_PARTICIPANTS,
        "currentParticipants": current_count,
        "eventHost": act.ACT_EVENT_HOST or "-",
        "guestSpeaker": act.ACT_GUEST_SPEAKER or "-",
        "foodInfo": act.ACT_FOOD_INFO or "-",
        "travelInfo": act.ACT_TRAVEL_INFO or "-",
        "moreDetails": act.ACT_MORE_DETAILS or "-",
        "actAttachments": act.ACT_ATTACHMENTS,
        "agenda": act.ACT_AGENDA,
        "targetCriteria": act.ACT_TARGET_CRITERIA,
        "isFavorite": is_fav,
        "isRegistered": is_registered,
        "sessions": sessions_data
    }

def count_target_employees(db: Session, target_criteria_json: str | None) -> int:
    """
    ฟังก์ชันนับจำนวนพนักงานที่ตรงตามเงื่อนไข (สำหรับคำนวณ Max Participants อัตโนมัติ)
    """
    # ดึงพนักงาน Active ทั้งหมดมาก่อน (หรือจะเขียน Query ซับซ้อนก็ได้ แต่วิธีนี้ชัวร์สุดเรื่อง Logic ภาษาไทย/Space)
    all_employees = db.query(models.Employee).filter(models.Employee.EMP_STATUS == 'Active').all()
    
    if not target_criteria_json:
        return len(all_employees) # ไม่ระบุ = ทั้งบริษัท

    try:
        criteria = json.loads(target_criteria_json)
        target_type = criteria.get('type', 'all')
        
        if target_type == 'all':
            return len(all_employees)
            
        if target_type == 'specific':
            target_depts = [d.strip() for d in criteria.get('departments', [])]
            target_positions = [p.strip() for p in criteria.get('positions', [])]
            
            count = 0
            for emp in all_employees:
                emp_dept = emp.department.DEP_NAME.strip() if emp.department else ""
                emp_pos = emp.EMP_POSITION.strip()
                
                # Logic เดิม: แผนกตรง OR ตำแหน่งตรง
                is_match = False
                if target_depts and emp_dept in target_depts:
                    is_match = True
                elif target_positions and emp_pos in target_positions:
                    is_match = True
                
                if is_match:
                    count += 1
            return count
            
        return len(all_employees) # Fallback
    except:
        return len(all_employees) # Error Fallback

@app.post("/activities")
def create_activity(req: ActivityFormRequest, emp_id: str = None, db: Session = Depends(get_db)):
    organizer_id = None
    if emp_id:
        org = db.query(models.Organizer).filter(models.Organizer.EMP_ID == emp_id).first()
        if org: organizer_id = org.ORG_ID
    
    if not organizer_id:
        first_org = db.query(models.Organizer).first()
        if first_org: organizer_id = first_org.ORG_ID
        else: raise HTTPException(status_code=400, detail="System has no organizer profile")

    try:
        data = req.ACTIVITY
        org_record = db.query(models.Organizer).filter(models.Organizer.ORG_ID == organizer_id).first()
        current_company_id = org_record.employee.COMPANY_ID

        if len(data.ACT_ATTACHMENTS) > 10:
            raise HTTPException(status_code=400, detail="Maximum 10 attachments allowed")

        final_dep_id = resolve_department_id(db, data.DEP_ID, current_company_id)

        new_act_id = generate_id("A")
        while db.query(models.Activity).filter(models.Activity.ACT_ID == new_act_id).first():
            new_act_id = generate_id("A")

        # [NEW LOGIC] คำนวณ Max Participants อัตโนมัติ ถ้าเป็นกิจกรรมบังคับ
        final_max_participants = data.ACT_MAX_PARTICIPANTS
        if data.ACT_ISCOMPULSORY == 1:
            # คำนวณจาก Target Criteria ที่ส่งมา
            final_max_participants = count_target_employees(db, data.ACT_TARGET_CRITERIA)
            print(f"Auto-calculated Max Participants: {final_max_participants}")

        new_activity = models.Activity(
            ACT_ID=new_act_id,
            COMPANY_ID=current_company_id,
            ACT_NAME=data.ACT_NAME,
            ACT_TYPE=data.ACT_TYPE,
            ACT_DESCRIPTIONS=data.ACT_DESCRIPTIONS,
            ORG_ID=organizer_id,
            DEP_ID=final_dep_id,
            ACT_ISCOMPULSORY=(data.ACT_ISCOMPULSORY == 1),
            ACT_POINT=data.ACT_POINT,
            ACT_COST=data.ACT_COST,
            ACT_PARTICIPATION_CONDITION=data.ACT_PARTICIPATION_CONDITION,
            ACT_STATUS=data.ACT_STATUS,
            ACT_MAX_PARTICIPANTS=final_max_participants, # ใช้ค่าที่คำนวณใหม่
            ACT_EVENT_HOST=data.ACT_EVENT_HOST,
            ACT_GUEST_SPEAKER=data.ACT_GUEST_SPEAKER,
            ACT_FOOD_INFO=data.ACT_FOOD_INFO,
            ACT_TRAVEL_INFO=data.ACT_TRAVEL_INFO,
            ACT_MORE_DETAILS=data.ACT_MORE_DETAILS,
            ACT_TARGET_CRITERIA=data.ACT_TARGET_CRITERIA,
            # [NEW] แปลง List เป็น JSON String ก่อนลง DB
            ACT_ATTACHMENTS=json.dumps([a.dict() for a in data.ACT_ATTACHMENTS]),
            ACT_AGENDA=data.ACT_AGENDA
        )
        db.add(new_activity)

        for s in req.SESSIONS:
            new_sess_id = generate_id("S", 6)
            while db.query(models.ActivitySession).filter(models.ActivitySession.SESSION_ID == new_sess_id).first():
                 new_sess_id = generate_id("S", 6)
            
            sess_date = datetime.strptime(s.SESSION_DATE.split('T')[0], "%Y-%m-%d").date()
            t_start = parse_time_safe(s.START_TIME)
            t_end = parse_time_safe(s.END_TIME)

            new_session = models.ActivitySession(
                SESSION_ID=new_sess_id,
                ACT_ID=new_act_id,
                SESSION_DATE=sess_date,
                START_TIME=t_start,
                END_TIME=t_end,
                LOCATION=s.LOCATION,
                SESSION_STATUS="Open"
            )
            db.add(new_session)
            
        # [LOGIC 3] แจ้งเตือน Employee: กิจกรรมบังคับ (Compulsory Activity Assigned)
        if data.ACT_ISCOMPULSORY == 1:
            # 1. หาพนักงานทั้งหมดที่ Active
            all_active_emps = db.query(models.Employee).filter(models.Employee.EMP_STATUS == 'Active').all()
            
            # 2. วนลูปเช็ค Target (ใช้ฟังก์ชัน check_is_target ที่มีอยู่แล้ว)
            # *หมายเหตุ: เพื่อประสิทธิภาพ ควรใช้ Background Tasks ในการส่งถ้าคนเยอะ*
            count_notified = 0
            for emp in all_active_emps:
                # เราต้อง Mock Object activity ชั่วคราวเพื่อส่งให้ฟังก์ชัน check
                # หรือเขียน Logic check ใหม่ตรงนี้
                # ในที่นี้สมมติว่าใช้ Logic เดียวกัน
                is_target = check_is_target(new_activity, emp)
            
            if is_target:
                create_notification_internal(
                    db,
                    emp_id=emp.EMP_ID,
                    title="📌 กิจกรรมบังคับใหม่",
                    message=f"คุณได้รับมอบหมายให้เข้าร่วม '{data.ACT_NAME}'",
                    notif_type="Activity",
                    target_role="Employee",
                    ref_id=new_act_id,
                    route_path="/activity_detail"
                )
                count_notified += 1
            
            print(f"Notify Compulsory: Sent to {count_notified} employees")
        
        if data.ACT_ISCOMPULSORY == 0 and data.ACT_TARGET_CRITERIA:
            all_active_emps = db.query(models.Employee).filter(models.Employee.EMP_STATUS == 'Active').all()
            
            count_targeted = 0
            for emp in all_active_emps:
                # ใช้ฟังก์ชัน check_is_target ตัวเดิม
                if check_is_target(new_activity, emp):
                    create_notification_internal(
                        db,
                        emp_id=emp.EMP_ID,
                        title="✨ กิจกรรมใหม่ที่คุณอาจสนใจ",
                        message=f"กิจกรรม '{data.ACT_NAME}' เปิดรับสมัครแล้ว! (ตรงกับสายงานคุณ)",
                        notif_type="Activity",
                        target_role="Employee",
                        ref_id=new_act_id,
                        route_path="/activity_detail"
                    )
                    count_targeted += 1
        
            print(f"Notify Targeted: Sent to {count_targeted} employees")

        db.commit()
        return {"message": "Activity created successfully", "actId": new_act_id}

    except Exception as e:
        db.rollback()
        print(f"Create Error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to create: {str(e)}")

@app.put("/activities/{act_id}")
async def update_activity(act_id: str, req: ActivityFormRequest, db: Session = Depends(get_db)):
    act = db.query(models.Activity).filter(models.Activity.ACT_ID == act_id).first()
    if not act:
        raise HTTPException(status_code=404, detail="Activity not found")

    data = req.ACTIVITY
    
    if len(data.ACT_ATTACHMENTS) > 10:
        raise HTTPException(status_code=400, detail="Maximum 10 attachments allowed")

    current_company_id = act.COMPANY_ID 
    final_dep_id = resolve_department_id(db, data.DEP_ID, current_company_id)

    act.ACT_NAME = data.ACT_NAME
    act.ACT_TYPE = data.ACT_TYPE
    act.ACT_DESCRIPTIONS = data.ACT_DESCRIPTIONS
    act.ACT_POINT = data.ACT_POINT
    act.ACT_GUEST_SPEAKER = data.ACT_GUEST_SPEAKER
    act.ACT_EVENT_HOST = data.ACT_EVENT_HOST
    # act.ACT_MAX_PARTICIPANTS = data.ACT_MAX_PARTICIPANTS # [MOVED]
    act.DEP_ID = final_dep_id 
    act.ACT_COST = data.ACT_COST
    act.ACT_TRAVEL_INFO = data.ACT_TRAVEL_INFO
    act.ACT_FOOD_INFO = data.ACT_FOOD_INFO
    act.ACT_MORE_DETAILS = data.ACT_MORE_DETAILS
    act.ACT_PARTICIPATION_CONDITION = data.ACT_PARTICIPATION_CONDITION
    act.ACT_ISCOMPULSORY = (data.ACT_ISCOMPULSORY == 1)
    act.ACT_STATUS = data.ACT_STATUS
    
    if hasattr(data, 'ACT_TARGET_CRITERIA'):
        act.ACT_TARGET_CRITERIA = data.ACT_TARGET_CRITERIA

    # [NEW LOGIC]
    if data.ACT_ISCOMPULSORY == 1:
        if hasattr(data, 'ACT_TARGET_CRITERIA'):
             act.ACT_MAX_PARTICIPANTS = count_target_employees(db, data.ACT_TARGET_CRITERIA)
    else:
        act.ACT_MAX_PARTICIPANTS = data.ACT_MAX_PARTICIPANTS

    # [NEW] อัปเดตเป็น JSON
    act.ACT_ATTACHMENTS = json.dumps([a.dict() for a in data.ACT_ATTACHMENTS])

    if act.organizer:
        act.organizer.ORG_CONTACT_INFO = req.ORGANIZER.ORG_CONTACT_INFO
    
    existing_sessions = db.query(models.ActivitySession).filter(
        models.ActivitySession.ACT_ID == act_id
    ).order_by(models.ActivitySession.SESSION_DATE).all()

    for i, s_data in enumerate(req.SESSIONS):
        try:
            sess_date = datetime.strptime(s_data.SESSION_DATE.split('T')[0], "%Y-%m-%d").date()
            t_start = parse_time_safe(s_data.START_TIME)
            t_end = parse_time_safe(s_data.END_TIME)
        except ValueError:
             continue 

        if i < len(existing_sessions):
            session = existing_sessions[i]
            session.SESSION_DATE = sess_date
            session.START_TIME = t_start
            session.END_TIME = t_end
            session.LOCATION = s_data.LOCATION
            
            if sess_date >= date.today():
                session.SESSION_STATUS = "Open"
                
        else:
            new_sess_id = generate_id("S", 6)
            while db.query(models.ActivitySession).filter(models.ActivitySession.SESSION_ID == new_sess_id).first():
                 new_sess_id = generate_id("S", 6)
            
            new_session = models.ActivitySession(
                SESSION_ID=new_sess_id,
                ACT_ID=act_id,
                SESSION_DATE=sess_date,
                START_TIME=t_start,
                END_TIME=t_end,
                LOCATION=s_data.LOCATION,
                SESSION_STATUS="Open"
            )
            db.add(new_session)
    
    if len(req.SESSIONS) < len(existing_sessions):
        for i in range(len(req.SESSIONS), len(existing_sessions)):
            sess_to_delete = existing_sessions[i]
            reg_count = db.query(models.Registration).filter(
                models.Registration.SESSION_ID == sess_to_delete.SESSION_ID
            ).count()
            
            if reg_count == 0:
                db.delete(sess_to_delete)
            else:
                print(f"Skipping delete session {sess_to_delete.SESSION_ID} due to existing registrations.")

    try:
        db.commit()
        await manager.broadcast("REFRESH_ACTIVITIES")
        return {"message": "Activity updated successfully"}
    except Exception as e:
        db.rollback()
        print(f"Update Error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to update: {str(e)}")

@app.get("/departments")
def get_departments(db: Session = Depends(get_db)):
    deps = db.query(models.Department).all()
    return [{"id": d.DEP_ID, "name": d.DEP_NAME} for d in deps]

@app.get("/positions")
def get_positions(db: Session = Depends(get_db)):
    positions = db.query(models.Employee.EMP_POSITION).distinct().all()
    return [p[0] for p in positions if p[0]]

def resolve_department_id(db: Session, dep_input: str, company_id: str):
    dep = db.query(models.Department).filter(models.Department.DEP_ID == dep_input).first()
    if dep:
        return dep.DEP_ID
    
    dep = db.query(models.Department).filter(
        models.Department.DEP_NAME == dep_input,
        models.Department.COMPANY_ID == company_id
    ).first()
    if dep:
        return dep.DEP_ID
    
    new_dep_id = generate_id("D")
    while db.query(models.Department).filter(models.Department.DEP_ID == new_dep_id).first():
            new_dep_id = generate_id("D")
    
    new_dep = models.Department(
        DEP_ID=new_dep_id,
        COMPANY_ID=company_id,
        DEP_NAME=dep_input
    )
    db.add(new_dep)
    db.commit() 
    db.refresh(new_dep)
    
    return new_dep.DEP_ID

@app.delete("/activities/{act_id}")
def delete_activity(act_id: str, db: Session = Depends(get_db)):
    act = db.query(models.Activity).filter(models.Activity.ACT_ID == act_id).first()
    if not act:
        raise HTTPException(status_code=404, detail="Activity not found")

    try:
        db.query(models.Favorite).filter(models.Favorite.ACT_ID == act_id).delete()
        db.query(models.Notification).filter(models.Notification.ACT_ID == act_id).delete()

        sessions = db.query(models.ActivitySession).filter(models.ActivitySession.ACT_ID == act_id).all()
        for s in sessions:
            db.query(models.Registration).filter(models.Registration.SESSION_ID == s.SESSION_ID).delete()
            db.query(models.CheckIn).filter(models.CheckIn.SESSION_ID == s.SESSION_ID).delete()

        db.query(models.ActivitySession).filter(models.ActivitySession.ACT_ID == act_id).delete()

        db.delete(act)
        db.commit()
        return {"message": "Activity deleted successfully"}

    except Exception as e:
        db.rollback()
        print(f"Delete Error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to delete: {str(e)}")

@app.get("/activities/{act_id}/participants", response_model=list[ParticipantResponse])
def get_activity_participants(act_id: str, db: Session = Depends(get_db)):
    # 1. ดึงข้อมูลกิจกรรม เพื่อเช็คว่าเป็น Compulsory หรือไม่
    activity = db.query(models.Activity).filter(models.Activity.ACT_ID == act_id).first()
    if not activity:
        return []

    sessions = db.query(models.ActivitySession).filter(models.ActivitySession.ACT_ID == act_id).all()
    session_ids = [s.SESSION_ID for s in sessions]
    
    # ดึงข้อมูลการเช็คอิน (เพื่อดูว่าใครมาแล้วบ้าง)
    checkins = db.query(models.CheckIn).filter(models.CheckIn.SESSION_ID.in_(session_ids)).all()
    checked_in_map = {c.EMP_ID: c.CHECKIN_TIME for c in checkins}

    results = []
    
    # --- LOGIC ใหม่: แยกตามประเภทกิจกรรม ---
    
    if activity.ACT_ISCOMPULSORY:
        # === กรณี กิจกรรมบังคับ (ดึงทุกคนที่เข้าข่าย Target) ===
        
        # 1. ดึงพนักงานทั้งหมดที่ Active
        all_employees = db.query(models.Employee).filter(models.Employee.EMP_STATUS == 'Active').all()
        
        # 2. Parse Target Criteria
        target_depts = []
        target_positions = []
        is_target_all = False
        
        if not activity.ACT_TARGET_CRITERIA:
            is_target_all = True
        else:
            try:
                criteria = json.loads(activity.ACT_TARGET_CRITERIA)
                if criteria.get('type') == 'all':
                    is_target_all = True
                else:
                    # เตรียมข้อมูล Target (ตัดช่องว่าง)
                    target_depts = [d.strip() for d in criteria.get('departments', [])]
                    target_positions = [p.strip() for p in criteria.get('positions', [])]
            except:
                is_target_all = True # Fail-safe

        # 3. วนลูปเช็คพนักงานทุกคน
        for emp in all_employees:
            is_match = False
            if is_target_all:
                is_match = True
            else:
                # เช็คแผนก
                emp_dept = emp.department.DEP_NAME.strip() if emp.department else ""
                if emp_dept in target_depts:
                    is_match = True
                # เช็คตำแหน่ง
                if not is_match:
                    emp_pos = emp.EMP_POSITION.strip()
                    if emp_pos in target_positions:
                        is_match = True
            
            if is_match:
                # กำหนดสถานะ: ถ้าเช็คอินแล้ว = Joined, ถ้ายัง = Assigned (แทน Registered)
                status = "Assigned" 
                check_in_time = "-"

                if emp.EMP_ID in checked_in_map:
                    status = "Joined"
                    t = checked_in_map[emp.EMP_ID]
                    check_in_time = t.strftime("%H:%M")
                
                results.append({
                    "empId": emp.EMP_ID,
                    "title": emp.EMP_TITLE_EN,
                    "name": emp.EMP_NAME_EN,
                    "department": emp.department.DEP_NAME if emp.department else "-",
                    "status": status,
                    "checkInTime": check_in_time
                })

    else:
        # === กรณี กิจกรรมทั่วไป (ดึงจาก Registration) === (Logic เดิม)
        if not session_ids: return []
        
        regs = db.query(models.Registration).filter(models.Registration.SESSION_ID.in_(session_ids)).all()
        processed_emp_ids = set()

        for r in regs:
            emp = r.employee
            if emp.EMP_ID in processed_emp_ids: continue
            processed_emp_ids.add(emp.EMP_ID)
            
            status = "Registered"
            check_in_time = "-"

            if emp.EMP_ID in checked_in_map:
                status = "Joined"
                t = checked_in_map[emp.EMP_ID]
                check_in_time = t.strftime("%H:%M")

            results.append({
                "empId": emp.EMP_ID,
                "title": emp.EMP_TITLE_EN,
                "name": emp.EMP_NAME_EN,
                "department": emp.department.DEP_NAME if emp.department else "-",
                "status": status,
                "checkInTime": check_in_time
            })
    
    return results


@app.post("/checkin")
async def process_checkin(req: CheckInRequest, db: Session = Depends(get_db)):
    # 1. ดึงข้อมูลพนักงาน
    employee = db.query(models.Employee).filter(models.Employee.EMP_ID == req.emp_id).first()
    if not employee:
        raise HTTPException(status_code=404, detail="ไม่พบข้อมูลพนักงาน")

    # 2. ดึงข้อมูลกิจกรรม
    activity = db.query(models.Activity).filter(models.Activity.ACT_ID == req.act_id).first()
    if not activity:
        raise HTTPException(status_code=404, detail="ไม่พบข้อมูลกิจกรรม")

    now = datetime.now()
    
    # 3. ดึง Session ของวันนี้
    sessions = db.query(models.ActivitySession).filter(
        models.ActivitySession.ACT_ID == req.act_id,
        models.ActivitySession.SESSION_DATE == now.date()
    ).all()

    if not sessions:
         raise HTTPException(status_code=400, detail="ไม่มีรอบกิจกรรมในวันนี้")

    target_session = None
    time_error_message = ""
    
    # 4. วนลูปหา Session (พร้อมแก้ Midnight Bug)
    for sess in sessions:
        start_dt = datetime.combine(sess.SESSION_DATE, sess.START_TIME)
        end_dt = datetime.combine(sess.SESSION_DATE, sess.END_TIME)
        
        # แก้บั๊กข้ามคืน
        if sess.END_TIME <= sess.START_TIME:
            end_dt += timedelta(days=1)

        window_open = start_dt - timedelta(hours=1)
        
        if activity.ACT_ISCOMPULSORY:
            window_close = start_dt + timedelta(minutes=30)
            condition_text = "ภายใน 30 นาทีแรก"
        else:
            window_close = end_dt 
            condition_text = "ก่อนกิจกรรมจบ"
            
        if window_open <= now <= window_close:
            target_session = sess
            break
        else:
            time_error_message = f"ไม่อยู่ในช่วงเวลาเช็คอิน ({condition_text})"

    if not target_session:
         raise HTTPException(status_code=400, detail=time_error_message or "ไม่อยู่ในช่วงเวลากิจกรรม")

    # 5. ตรวจสอบการลงทะเบียน
    reg = db.query(models.Registration).filter(
        models.Registration.EMP_ID == req.emp_id,
        models.Registration.SESSION_ID == target_session.SESSION_ID
    ).first()
    
    # 6. ตรวจสอบสิทธิ์
    is_authorized = False
    if reg:
        is_authorized = True
    elif activity.ACT_ISCOMPULSORY:
        if check_is_target(activity, employee):
            is_authorized = True
            
    if not is_authorized:
        raise HTTPException(status_code=400, detail="พนักงานยังไม่ได้ลงทะเบียน หรือไม่อยู่ในกลุ่มเป้าหมาย")

    # 7. ตรวจสอบเช็คอินซ้ำ
    existing_checkin = db.query(models.CheckIn).filter(
        models.CheckIn.EMP_ID == req.emp_id,
        models.CheckIn.SESSION_ID == target_session.SESSION_ID
    ).first()
    
    if existing_checkin:
        raise HTTPException(status_code=400, detail="พนักงานเช็คอินเรียบร้อยแล้ว")

    try:
        # 8. บันทึกข้อมูล
        new_checkin_id = generate_id("CI", 8)
        points_to_give = activity.ACT_POINT
        
        new_checkin = models.CheckIn(
            CHECKIN_ID=new_checkin_id,
            EMP_ID=req.emp_id,
            SESSION_ID=target_session.SESSION_ID,
            CHECKIN_DATE=now.date(),
            CHECKIN_TIME=now.time(),
            POINTS_EARNED=points_to_give
        )
        db.add(new_checkin)
        
        emp_points = db.query(models.Points).filter(models.Points.EMP_ID == req.emp_id).first()
        if not emp_points:
            emp_points = models.Points(EMP_ID=req.emp_id, TOTAL_POINTS=0)
            db.add(emp_points)
            
        emp_points.TOTAL_POINTS += points_to_give
        
        txn_id = generate_id("TXN", 8)
        new_txn = models.PointTransaction(
            TXN_ID=txn_id,
            EMP_ID=req.emp_id,
            TXN_TYPE="Earn",
            REF_TYPE="CHECKIN",
            REF_ID=new_checkin_id,
            POINTS=points_to_give,
            TXN_DATE=now
        )
        db.add(new_txn)
        
        # 11. สร้าง Notification ลง DB
        create_notification_internal(
            db,
            emp_id=req.emp_id,
            title="เช็คอินสำเร็จ! 🎉",
            message=f"ยินดีด้วย! คุณได้รับ {points_to_give} คะแนนจากกิจกรรม '{activity.ACT_NAME}'",
            notif_type="System",
            ref_id=req.act_id,
            route_path="/profile"
        )
        
        db.commit()
        
        # 12. ส่งสัญญาณ Real-time
        
        # [FIXED] เพิ่มบรรทัดนี้: แจ้งเตือน Employee ว่ามี Notification ใหม่ (เพื่อให้เด้ง Toast / Badge)
        await manager.send_personal_message("REFRESH_NOTIFICATIONS", req.emp_id)
        
        # แจ้งเตือน Organizer (เพื่อให้ List อัปเดต)
        await manager.broadcast("REFRESH_PARTICIPANTS")
        
        # แจ้งเตือน Employee (สำหรับ Logic หน้า Checkin Success)
        await manager.broadcast(f"CHECKIN_SUCCESS|{req.emp_id}|{activity.ACT_NAME}|{req.scanned_by}")
        
        return {
            "status": "success",
            "message": f"เช็คอินสำเร็จ! คุณได้รับ {points_to_give} คะแนน",
            "emp_name": employee.EMP_NAME_EN,
            "points_earned": points_to_give,
            "checkin_time": now.strftime("%H:%M")
        }
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database Error: {str(e)}")

# ไฟล์: lib/backend_api/main.py

# ... (ส่วน import ด้านบนคงเดิม) ...

@app.get("/my-activities/{emp_id}", response_model=list[MyActivityResponse])
def get_my_upcoming_activities(emp_id: str, db: Session = Depends(get_db)):
    # [NEW] ใช้เวลาปัจจุบันแบบละเอียด
    now = datetime.now()
    today = date.today()
    yesterday = today - timedelta(days=1)
    # 1. ดึงข้อมูลพนักงาน
    employee = db.query(models.Employee).filter(models.Employee.EMP_ID == emp_id).first()
    if not employee:
        raise HTTPException(status_code=404, detail="Employee not found")
        
    emp_dept_name = employee.department.DEP_NAME.strip() if employee.department else ""
    emp_position = employee.EMP_POSITION.strip()
    
    # 2. ดึงกิจกรรมที่ "ลงทะเบียนแล้ว" (Registered)
    registered_acts = db.query(
        models.Registration, models.ActivitySession, models.Activity
    ).join(
        models.ActivitySession, models.Registration.SESSION_ID == models.ActivitySession.SESSION_ID
    ).join(
        models.Activity, models.ActivitySession.ACT_ID == models.Activity.ACT_ID
    ).outerjoin(
        models.CheckIn, 
        (models.CheckIn.SESSION_ID == models.Registration.SESSION_ID) & 
        (models.CheckIn.EMP_ID == models.Registration.EMP_ID)
    ).filter(
        models.Registration.EMP_ID == emp_id,
        # [FIXED] เปลี่ยนจาก >= today เป็น >= yesterday
        models.ActivitySession.SESSION_DATE >= yesterday, 
        models.CheckIn.CHECKIN_ID == None  # ยังไม่เช็คอิน
    ).all()

    registered_act_ids = {act.ACT_ID for _, _, act in registered_acts}
    output = []

    for reg, sess, act in registered_acts:
        # [NEW LOGIC] เช็คเวลาจบแบบละเอียด (ตัดกิจกรรมที่จบไปแล้วออก)
        sess_end_dt = datetime.combine(sess.SESSION_DATE, sess.END_TIME)
        if sess.END_TIME <= sess.START_TIME:
             sess_end_dt += timedelta(days=1) # แก้บั๊กข้ามคืน
             
        # ถ้าเวลาปัจจุบัน เลยเวลาจบไปแล้ว -> ไม่เอามาแสดงใน Upcoming
        if now > sess_end_dt:
            continue

        output.append({
            "actId": act.ACT_ID,
            "actType": act.ACT_TYPE,
            "name": act.ACT_NAME,
            "location": sess.LOCATION,
            "activityDate": sess.SESSION_DATE,
            "startTime": sess.START_TIME.strftime("%H:%M"),
            "endTime": sess.END_TIME.strftime("%H:%M"),
            "status": sess.SESSION_STATUS,
            "sessionId": sess.SESSION_ID,
            "isCompulsory": act.ACT_ISCOMPULSORY == 1,
            "point": act.ACT_POINT
        })

    # 3. ดึงกิจกรรม "บังคับ" (Compulsory) ที่ยังไม่จบ
    compulsory_acts = db.query(models.Activity).join(models.ActivitySession).filter(
        models.Activity.ACT_ISCOMPULSORY == True,
        models.Activity.ACT_STATUS == 'Open',
        # [FIXED] เปลี่ยนจาก >= today เป็น >= yesterday เช่นกัน
        models.ActivitySession.SESSION_DATE >= yesterday 
    ).distinct().all()

    for act in compulsory_acts:
        if act.ACT_ID in registered_act_ids:
            continue 
            
        # --- Target Checking ---
        is_target = False
        if not act.ACT_TARGET_CRITERIA:
            is_target = True
        else:
            try:
                criteria = json.loads(act.ACT_TARGET_CRITERIA)
                target_type = criteria.get('type', 'all')
                
                if target_type == 'all':
                    is_target = True
                elif target_type == 'specific':
                    target_depts = criteria.get('departments', [])
                    target_positions = criteria.get('positions', [])

                    if target_depts and emp_dept_name.strip() in [d.strip() for d in target_depts]:
                        is_target = True
                    if not is_target and target_positions:
                        if emp_position.strip() in [p.strip() for p in target_positions]:
                            is_target = True
            except:
                is_target = True

        if is_target:
            # หา Session ที่ยังไม่จบ
            valid_sessions = []
            for s in act.sessions:
                 s_end_dt = datetime.combine(s.SESSION_DATE, s.END_TIME)
                 if s.END_TIME <= s.START_TIME:
                     s_end_dt += timedelta(days=1)
                 
                 # เอาเฉพาะรอบที่ยังไม่หมดเวลา
                 if s_end_dt >= now and s.SESSION_STATUS == 'Open':
                     valid_sessions.append(s)
            
            if not valid_sessions: continue
            
            # เลือกรอบที่เร็วที่สุด
            target_session = sorted(valid_sessions, key=lambda x: (x.SESSION_DATE, x.START_TIME))[0]
            
            output.append({
                "actId": act.ACT_ID,
                "actType": act.ACT_TYPE,
                "name": act.ACT_NAME,
                "location": target_session.LOCATION,
                "activityDate": target_session.SESSION_DATE,
                "startTime": target_session.START_TIME.strftime("%H:%M"),
                "endTime": target_session.END_TIME.strftime("%H:%M"),
                "status": "Auto-Added",
                "sessionId": target_session.SESSION_ID,
                "isCompulsory": True,
                "point": act.ACT_POINT
            })
        
    output.sort(key=lambda x: (x['activityDate'], x['startTime']))
    return output[:10]
@app.post("/favorites/toggle")
def toggle_favorite(req: ToggleFavoriteRequest, db: Session = Depends(get_db)):
    existing_fav = db.query(models.Favorite).filter(
        models.Favorite.EMP_ID == req.emp_id,
        models.Favorite.ACT_ID == req.act_id
    ).first()

    if existing_fav:
        db.delete(existing_fav)
        db.commit()
        return {"status": "removed", "message": "Removed from favorites"}
    else:
        new_fav_id = generate_id("F")
        new_fav = models.Favorite(
            FAV_ID=new_fav_id,
            EMP_ID=req.emp_id,
            ACT_ID=req.act_id,
            FAV_DATE=date.today()
        )
        db.add(new_fav)
        db.commit()
        return {"status": "added", "message": "Added to favorites"}

@app.get("/favorites/{emp_id}")
def get_user_favorites(emp_id: str, db: Session = Depends(get_db)):
    favs = db.query(models.Favorite.ACT_ID).filter(models.Favorite.EMP_ID == emp_id).all()
    return [f[0] for f in favs]

@app.get("/my-registrations/{emp_id}", response_model=list[MyActivityResponse])
def get_my_registrations(emp_id: str, db: Session = Depends(get_db)):
    now = datetime.now() # ใช้เวลาปัจจุบันแบบละเอียด
    
    # 1. ดึงข้อมูลพนักงาน
    employee = db.query(models.Employee).filter(models.Employee.EMP_ID == emp_id).first()
    if not employee:
        raise HTTPException(status_code=404, detail="Employee not found")

    # เตรียมข้อมูลพนักงาน (ตัดช่องว่างเพื่อความแม่นยำ)
    emp_dept_name = employee.department.DEP_NAME.strip() if employee.department else ""
    emp_position = employee.EMP_POSITION.strip()
    
    # 2. ดึงรายการที่ "ลงทะเบียนแล้ว"
    regs = db.query(models.Registration).filter(models.Registration.EMP_ID == emp_id).all()
    
    output = []
    registered_act_ids = set() # เก็บ ID ไว้กันซ้ำ

    for r in regs:
        # --- [ส่วนที่ต้องมี] ดึงข้อมูล Session และ Activity ก่อน ---
        sess = db.query(models.ActivitySession).filter(models.ActivitySession.SESSION_ID == r.SESSION_ID).first()
        if not sess: continue
        
        act = db.query(models.Activity).filter(models.Activity.ACT_ID == sess.ACT_ID).first()
        if not act: continue
        # -----------------------------------------------------
        
        registered_act_ids.add(act.ACT_ID)

        # [NEW LOGIC] สร้าง DateTime ของเวลาจบกิจกรรม เพื่อเช็ค Missed
        # รองรับกรณีเวลาจบข้ามวัน (ถ้า End < Start ให้บวก 1 วัน)
        sess_end_dt = datetime.combine(sess.SESSION_DATE, sess.END_TIME)
        if sess.END_TIME <= sess.START_TIME:
             sess_end_dt += timedelta(days=1)

        checkin = db.query(models.CheckIn).filter(
            models.CheckIn.EMP_ID == emp_id, 
            models.CheckIn.SESSION_ID == sess.SESSION_ID
        ).first()
        
        status = "Upcoming"
        
        if checkin:
            status = "Joined"
        elif now > sess_end_dt: # เช็คเวลาปัจจุบันเทียบกับเวลาจบ
            status = "Missed"   # ถ้าเลยเวลาจบแล้ว และยังไม่เช็คอิน = Missed
        
        output.append({
            "actId": act.ACT_ID,
            "actType": act.ACT_TYPE,
            "name": act.ACT_NAME,
            "location": sess.LOCATION,
            "activityDate": sess.SESSION_DATE,
            "startTime": sess.START_TIME.strftime("%H:%M"),
            "endTime": sess.END_TIME.strftime("%H:%M"),
            "status": status,
            "sessionId": sess.SESSION_ID,
            "isCompulsory": act.ACT_ISCOMPULSORY == 1,
            "point": act.ACT_POINT
        })

    # 3. ดึงกิจกรรมบังคับ (Compulsory) ที่ "ยังไม่ได้ลงทะเบียน"
    compulsory_acts = db.query(models.Activity).filter(
        models.Activity.ACT_ISCOMPULSORY == True,
        models.Activity.ACT_STATUS == 'Open'
    ).all()

    for act in compulsory_acts:
        if act.ACT_ID in registered_act_ids:
            continue

        # --- Target Checking Logic ---
        is_target = False
        if not act.ACT_TARGET_CRITERIA:
            is_target = True
        else:
            try:
                criteria = json.loads(act.ACT_TARGET_CRITERIA)
                target_type = criteria.get('type', 'all')
                
                if target_type == 'all':
                    is_target = True
                elif target_type == 'specific':
                    target_depts = criteria.get('departments', [])
                    target_positions = criteria.get('positions', [])
                    
                    if target_depts and emp_dept_name in [d.strip() for d in target_depts]:
                        is_target = True
                    
                    if not is_target and target_positions:
                        if emp_position in [p.strip() for p in target_positions]:
                            is_target = True
            except:
                is_target = True

        if is_target:
            sessions = sorted(act.sessions, key=lambda x: (x.SESSION_DATE, x.START_TIME))
            if not sessions: continue

            # แบ่งรอบ อดีต/อนาคต โดยเทียบกับ now (datetime)
            future_sessions = []
            past_sessions = []
            
            for s in sessions:
                s_end_dt = datetime.combine(s.SESSION_DATE, s.END_TIME)
                # รองรับกรณีข้ามวัน
                if s.END_TIME <= s.START_TIME:
                     s_end_dt += timedelta(days=1)

                if s_end_dt >= now:
                    future_sessions.append(s)
                else:
                    past_sessions.append(s)
            
            target_session = None
            derived_status = "Upcoming"

            if future_sessions:
                target_session = future_sessions[0]
                derived_status = "Upcoming"
            elif past_sessions:
                target_session = past_sessions[-1]
                derived_status = "Missed"
            
            if target_session:
                 output.append({
                    "actId": act.ACT_ID,
                    "actType": act.ACT_TYPE,
                    "name": act.ACT_NAME,
                    "location": target_session.LOCATION,
                    "activityDate": target_session.SESSION_DATE,
                    "startTime": target_session.START_TIME.strftime("%H:%M"),
                    "endTime": target_session.END_TIME.strftime("%H:%M"),
                    "status": derived_status,
                    "sessionId": target_session.SESSION_ID,
                    "isCompulsory": True,
                    "point": act.ACT_POINT
                })
    
    output.sort(key=lambda x: x['activityDate'], reverse=True)
        
    return output


@app.post("/activities/register")
async def register_activity(req: ActivityRegisterRequest, db: Session = Depends(get_db)):
    # 1. เช็คว่าเคยลงหรือยัง (เหมือนเดิม)
    existing = db.query(models.Registration).filter(
        models.Registration.EMP_ID == req.emp_id,
        models.Registration.SESSION_ID == req.session_id
    ).first()
    
    if existing:
        raise HTTPException(status_code=400, detail="Already registered")

    # 2. [NEW] ดึงข้อมูล Session และ Activity เพื่อเช็คโควตา
    session = db.query(models.ActivitySession).filter(models.ActivitySession.SESSION_ID == req.session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
        
    activity = session.activity # ใช้ Relationship ดึง Activity แม่
    
    # 2.1 นับจำนวนคนที่ลงทะเบียนใน Session นี้ไปแล้ว
    current_count = db.query(models.Registration).filter(
        models.Registration.SESSION_ID == req.session_id
    ).count()
    
    # 2.2 เทียบกับ Max Participants
    # ถ้า activity.ACT_MAX_PARTICIPANTS เป็น 0 หรือ น้อยกว่า อาจจะหมายถึงไม่จำกัด? 
    # แต่ปกติควรระบุค่าเสมอ สมมติว่าถ้า > 0 คือจำกัด
    if activity.ACT_MAX_PARTICIPANTS > 0 and current_count >= activity.ACT_MAX_PARTICIPANTS:
         raise HTTPException(status_code=400, detail="Activity is fully booked (ที่นั่งเต็มแล้ว)")

    try:
        # 3. ถ้ายังไม่เต็ม -> สร้างใบลงทะเบียน (เหมือนเดิม)
        new_reg_id = generate_id("R", 8)
        new_reg = models.Registration(
            REG_ID=new_reg_id,
            EMP_ID=req.emp_id,
            SESSION_ID=req.session_id,
            REG_DATE=date.today()
        )
        db.add(new_reg)

        # 4. สร้าง Notification (เหมือนเดิม)
        create_notification_internal(
            db, 
            emp_id=req.emp_id,
            title="ลงทะเบียนสำเร็จ ✅",
            message=f"คุณได้ลงทะเบียนกิจกรรม '{activity.ACT_NAME}' เรียบร้อยแล้ว",
            notif_type="Activity",
            ref_id=activity.ACT_ID,
            route_path="/activity_detail"
        )

        db.commit()
        
        organizer_emp_id = None
        if activity.organizer:
             organizer_emp_id = activity.organizer.EMP_ID
        
        if organizer_emp_id:
            # 2. คำนวณ %
            # นับจำนวนล่าสุด
            current_reg_count = db.query(models.Registration).filter(
                models.Registration.SESSION_ID == req.session_id
            ).count()
            
            max_p = activity.ACT_MAX_PARTICIPANTS
            if max_p > 0:
                percent = (current_reg_count / max_p) * 100
                
                milestone_title = ""
                milestone_msg = ""
                
                # เช็ค Milestone (50%, 80%, 100%)
                # ใช้ logic == หรือ >= ในช่วงแคบๆ เพื่อกันส่งซ้ำ (ในที่นี้เอาแบบง่ายคือเช็คจังหวะข้ามผ่าน)
                # *หมายเหตุ: ใน Production จริงควรมี Flag เก็บว่าแจ้งไปหรือยัง แต่ใน Demo ใช้แบบนี้พอได้
                
                if current_reg_count == max_p:
                    milestone_title = "🚀 ลงทะเบียนเต็มแล้ว!"
                    milestone_msg = f"กิจกรรม '{activity.ACT_NAME}' มีผู้ลงทะเบียนครบ {max_p} คนแล้ว"
                elif current_reg_count == int(max_p * 0.8):
                     milestone_title = "🔥 ฮอตมาก! ยอดทะลุ 80%"
                     milestone_msg = f"กิจกรรม '{activity.ACT_NAME}' ใกล้เต็มแล้ว ({current_reg_count}/{max_p})"
                elif current_reg_count == int(max_p * 0.5):
                     milestone_title = "📈 ยอดถึง 50% แล้ว"
                     milestone_msg = f"กิจกรรม '{activity.ACT_NAME}' มาถึงครึ่งทางแล้ว"

                if milestone_title:
                    create_notification_internal(
                        db,
                        emp_id=organizer_emp_id,
                        title=milestone_title,
                        message=milestone_msg,
                        notif_type="System", # หรือประเภทใหม่ Organizer
                        target_role="Organizer", # [สำคัญ] ระบุว่าส่งให้ Role ไหน
                        ref_id=activity.ACT_ID,
                        route_path="/participants" # กดแล้วไปหน้าดูรายชื่อ
                    )
                    # ยิง Socket ให้ Organizer
                    await manager.send_personal_message("REFRESH_NOTIFICATIONS", organizer_emp_id)

        # 5. Broadcast Real-time (เหมือนเดิม)
        await manager.broadcast("REFRESH_PARTICIPANTS")
        await manager.broadcast("REFRESH_ACTIVITIES") 
        await manager.send_personal_message("REFRESH_NOTIFICATIONS", req.emp_id)
        
        return {"message": "Registration successful", "reg_id": new_reg_id}

    except HTTPException as he:
        raise he
    except Exception as e:
        db.rollback()
        print(f"Register Error: {e}")
        raise HTTPException(status_code=500, detail=f"System Error: {str(e)}")


@app.post("/activities/unregister")
async def unregister_activity(req: UnregisterRequest, db: Session = Depends(get_db)):
    reg = db.query(models.Registration).filter(
        models.Registration.EMP_ID == req.emp_id,
        models.Registration.SESSION_ID == req.session_id
    ).first()
    
    if not reg:
        raise HTTPException(status_code=404, detail="Registration not found")
        
    session = db.query(models.ActivitySession).filter(
        models.ActivitySession.SESSION_ID == req.session_id
    ).first()
    
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    activity = db.query(models.Activity).filter(
        models.Activity.ACT_ID == session.ACT_ID
    ).first()
    
    if activity.ACT_ISCOMPULSORY:
        raise HTTPException(status_code=400, detail="กิจกรรมบังคับ ไม่สามารถยกเลิกได้")

    # เช็คเวลาล่วงหน้า 24 ชม.
    session_datetime = datetime.combine(session.SESSION_DATE, session.START_TIME)
    if session_datetime - datetime.now() < timedelta(hours=24):
        raise HTTPException(status_code=400, detail="ไม่สามารถยกเลิกได้ (ต้องล่วงหน้า 24 ชม.)")
    
    try:
        db.delete(reg) 
        
        create_notification_internal(
            db,
            emp_id=req.emp_id,
            title="ยกเลิกกิจกรรมสำเร็จ 🗑️", 
            message=f"คุณได้ยกเลิกการลงทะเบียน '{activity.ACT_NAME}' เรียบร้อยแล้ว",
            notif_type="Activity", 
            target_role="Employee",
            ref_id=activity.ACT_ID,
            route_path="/activity_detail"
        )
        
        db.commit() 

        # --- Broadcast Updates ---
        await manager.broadcast("REFRESH_PARTICIPANTS")
        await manager.broadcast("REFRESH_ACTIVITIES") 
        
        # [FIX] เพิ่มบรรทัดนี้: แจ้งเตือนตัวเลขแดงๆ ทันที
        await manager.send_personal_message("REFRESH_NOTIFICATIONS", req.emp_id)

        return {"message": "Unregistered successfully"}

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

# [NEW API] Upload Image
@app.post("/upload/image")
async def upload_image(file: UploadFile = File(...)):
    try:
        file_name = f"{datetime.now().timestamp()}_{file.filename}"
        file_location = f"static/{file_name}"
        
        with open(file_location, "wb+") as file_object:
            shutil.copyfileobj(file.file, file_object)
            
        return {"url": f"/static/{file_name}"} 
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Could not upload file: {e}")

@app.get("/rewards", response_model=list[PrizeResponse])
def get_rewards(db: Session = Depends(get_db)):
    prizes = db.query(models.Prize).filter(models.Prize.STATUS != 'Discontinued').all()
    results = []
    for p in prizes:
        prize_type_str = str(p.PRIZE_TYPE) if p.PRIZE_TYPE else 'Physical'
        
        images_list = []
        if p.PRIZE_IMAGES:
            try:
                images_list = json.loads(p.PRIZE_IMAGES)
            except:
                images_list = []
        
        if not images_list and hasattr(p, 'PRIZE_IMAGE') and p.PRIZE_IMAGE:
            images_list = [p.PRIZE_IMAGE]

        results.append({
            "id": p.PRIZE_ID,
            "name": p.PRIZE_NAME,
            "pointCost": p.PRIZE_POINTS,
            "description": p.PRIZE_DESCRIPTION or "-",
            "images": images_list,
            "stock": p.STOCK,
            "category": "General",
            "status": p.STATUS,
            "prizeType": prize_type_str,
        })
    return results

# [FIXED API] ดึงประวัติการแลกของรางวัล (รองรับหลายรูป)
@app.get("/my-redemptions/{emp_id}", response_model=list[MyRedemptionResponse])
def get_my_redemptions(emp_id: str, db: Session = Depends(get_db)):
    # 1. ดึงข้อมูลการแลก
    redemptions = db.query(models.Redeem).filter(models.Redeem.EMP_ID == emp_id).order_by(models.Redeem.REDEEM_DATE.desc()).all()
    
    results = []
    for r in redemptions:
        # 2. ดึงข้อมูลของรางวัล
        prize = db.query(models.Prize).filter(models.Prize.PRIZE_ID == r.PRIZE_ID).first()
        
        if not prize:
            continue

        # 3. [Logic] แกะ JSON รูปภาพ (PRIZE_IMAGES -> images list)
        img_list = []
        if prize.PRIZE_IMAGES:
            try:
                # แปลง JSON String กลับเป็น List
                img_list = json.loads(prize.PRIZE_IMAGES)
            except:
                img_list = []
        
        # Fallback สำหรับข้อมูลเก่า
        if not img_list and hasattr(prize, 'PRIZE_IMAGE') and prize.PRIZE_IMAGE:
             img_list = [prize.PRIZE_IMAGE]

        results.append({
            "redeemId": r.REDEEM_ID,
            "prizeName": prize.PRIZE_NAME,
            "pointCost": prize.PRIZE_POINTS,
            "redeemDate": r.REDEEM_DATE,
            "status": r.STATUS,
            "images": img_list, # ส่งเป็น List ให้ตรงกับ Schema ใหม่
            "pickupInstruction": prize.PICKUP_INSTRUCTION or "Contact HR"
        })
        
    return results

@app.post("/rewards/redeem")
async def redeem_reward(req: RedeemRequest, db: Session = Depends(get_db)):
    emp_points = db.query(models.Points).filter(models.Points.EMP_ID == req.emp_id).first()
    if not emp_points:
        emp_points = models.Points(EMP_ID=req.emp_id, TOTAL_POINTS=0)
        db.add(emp_points)
    
    prize = db.query(models.Prize).filter(models.Prize.PRIZE_ID == req.prize_id).first()
    if not prize:
        raise HTTPException(status_code=404, detail="Prize not found")
        
    if prize.STOCK <= 0:
        raise HTTPException(status_code=400, detail="Out of Stock")
    if emp_points.TOTAL_POINTS < prize.PRIZE_POINTS:
        raise HTTPException(status_code=400, detail="Insufficient Points")
        
    try:
        # --- 1. ตัดแต้มและสต็อก ---
        emp_points.TOTAL_POINTS -= prize.PRIZE_POINTS
        prize.STOCK -= 1
        
        voucher_code = None
        usage_expire = None
        status = "Pending"
        
        if prize.PRIZE_TYPE == 'Privilege':
            status = "Completed"
            this_year = datetime.now().year
            usage_expire = datetime(this_year, 12, 31, 23, 59, 59)
            
        elif prize.PRIZE_TYPE == 'Digital':
            status = "Pending"
            
        new_redeem_id = generate_id("RD", 8)
        new_redeem = models.Redeem(
            REDEEM_ID=new_redeem_id,
            EMP_ID=req.emp_id,
            PRIZE_ID=req.prize_id,
            REDEEM_DATE=datetime.now(),
            STATUS=status,
            APPROVED_BY=None,
            VOUCHER_CODE=voucher_code,
            USAGE_EXPIRED_DATE=usage_expire
        )
        db.add(new_redeem)
        
        new_txn_id = generate_id("TXN", 10)
        new_txn = models.PointTransaction(
            TXN_ID=new_txn_id,
            EMP_ID=req.emp_id,
            TXN_TYPE="Redeem",
            REF_TYPE="REDEEM",
            REF_ID=new_redeem_id,
            POINTS=-prize.PRIZE_POINTS,
            TXN_DATE=datetime.now()
        )
        db.add(new_txn)

        # --- 2. ส่วนแจ้งเตือน Admin (DEBUG & LOGIC ใหม่) ---
        # [ระวัง: บรรทัดข้างล่างต้องย่อหน้าเท่ากับ db.add ด้านบน]
        current_prize_type = str(prize.PRIZE_TYPE).strip().lower()
        print(f"DEBUG: Redeeming {prize.PRIZE_NAME} (Type: {current_prize_type}, Status: {status})")

        # เตรียมรายชื่อ Admin
        all_employees = db.query(models.Employee).all()
        admins = [e for e in all_employees if str(e.EMP_ROLE).strip().lower() == 'admin']
        
        # CASE A: ของที่ต้องดำเนินการ (Physical = ส่งของ, Digital = ส่งโค้ด)
        # เงื่อนไข: เป็น Physical หรือ Digital และสถานะต้องเป็น Pending
        if (current_prize_type == 'physical' or current_prize_type == 'digital') and status == 'Pending':
            print(f"DEBUG: Notify {len(admins)} admins for Pending Request")
            for admin in admins:
                create_notification_internal(
                    db,
                    emp_id=admin.EMP_ID,
                    title="มีคำขอแลกรางวัลใหม่ 🎁",
                    # เพิ่ม Type ในข้อความเพื่อให้ Admin รู้ทันทีว่าต้องทำอะไร
                    message=f"[{prize.PRIZE_TYPE}] พนักงาน {req.emp_id} ขอแลก '{prize.PRIZE_NAME}'",
                    notif_type="Reward",
                    target_role="Admin",
                    ref_id=new_redeem_id,
                    route_path="/admin/redemptions"
                )
                
        # CASE B: สิทธิพิเศษ (Privilege)
        # เงื่อนไข: เป็น Privilege (ซึ่งปกติจะ Auto-Complete) -> แจ้งเพื่อทราบ
        elif current_prize_type == 'privilege':
            print(f"DEBUG: Notify {len(admins)} admins for Privilege Usage")
            for admin in admins:
                create_notification_internal(
                    db,
                    emp_id=admin.EMP_ID,
                    title="มีการใช้สิทธิ์รางวัล ✨",
                    message=f"พนักงาน {req.emp_id} ได้ใช้สิทธิ์ '{prize.PRIZE_NAME}' เรียบร้อยแล้ว",
                    notif_type="Reward", # หรือจะใช้ System ก็ได้ถ้าไม่อยากให้เด่นมาก
                    target_role="Admin",
                    ref_id=new_redeem_id,
                    route_path="/admin/redemptions" # กดไปดูประวัติได้
                )

        # [LOGIC เดิม] Stock Low Warning
        if prize.STOCK < 5: 
            for admin in admins:
                create_notification_internal(
                    db,
                    emp_id=admin.EMP_ID,
                    title="⚠️ ของรางวัลใกล้หมด",
                    message=f"'{prize.PRIZE_NAME}' เหลือเพียง {prize.STOCK} ชิ้น กรุณาเติมสต็อก",
                    notif_type="Alert",
                    target_role="Admin",
                    ref_id=prize.PRIZE_ID,
                    route_path="/admin/rewards"
                )
        
        # --- 3. Commit ---
        db.commit()
        await manager.broadcast("REFRESH_REWARDS")
        await manager.send_personal_message("REFRESH_NOTIFICATIONS", req.emp_id)
        
        return {
            "message": "Redemption successful", 
            "remaining_points": emp_points.TOTAL_POINTS,
            "redeem_id": new_redeem_id
        }
        
    except Exception as e:
        db.rollback()
        print(f"Redeem Error: {e}")
        raise HTTPException(status_code=500, detail=f"Transaction failed: {str(e)}")
@app.post("/rewards/cancel")
async def cancel_redemption(req: CancelRedeemRequest, db: Session = Depends(get_db)):
    redeem = db.query(models.Redeem).filter(
        models.Redeem.REDEEM_ID == req.redeem_id,
        models.Redeem.EMP_ID == req.emp_id
    ).first()
    
    if not redeem:
        raise HTTPException(status_code=404, detail="Redemption record not found")
        
    if redeem.STATUS != 'Pending':
        raise HTTPException(status_code=400, detail="Cannot cancel completed or already cancelled item")

    prize = db.query(models.Prize).filter(models.Prize.PRIZE_ID == redeem.PRIZE_ID).first()
    emp_points = db.query(models.Points).filter(models.Points.EMP_ID == req.emp_id).first()
    
    try:
        redeem.STATUS = 'Cancelled'
        
        if prize:
            prize.STOCK += 1
            
        if emp_points and prize:
            emp_points.TOTAL_POINTS += prize.PRIZE_POINTS
            
            new_txn_id = generate_id("TXN", 10)
            new_txn = models.PointTransaction(
                TXN_ID=new_txn_id,
                EMP_ID=req.emp_id,
                TXN_TYPE="Refund",
                REF_TYPE="REDEEM",
                REF_ID=redeem.REDEEM_ID,
                POINTS=prize.PRIZE_POINTS,
                TXN_DATE=datetime.now()
            )
            db.add(new_txn)
            
        db.commit()
        await manager.broadcast("REFRESH_REWARDS")
        await manager.send_personal_message("REFRESH_NOTIFICATIONS", req.emp_id)
        
        return {
            "message": "Cancelled successfully", 
            "remaining_points": emp_points.TOTAL_POINTS if emp_points else 0
        }
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Cancel failed: {str(e)}")

@app.get("/admin/employees")
def get_all_employees(db: Session = Depends(get_db)):
    employees = db.query(models.Employee).all()
    results = []
    for e in employees:
        results.append({
            "id": e.EMP_ID,
            "name": e.EMP_NAME_EN,
            "title": e.EMP_TITLE_EN,
            "position": e.EMP_POSITION,
            "phone": e.EMP_PHONE,
            "email": e.EMP_EMAIL,
            "department": e.department.DEP_NAME if e.department else "-",
            "role": e.EMP_ROLE,
            "status": e.EMP_STATUS
        })
    return results

@app.delete("/admin/employees/{emp_id}")
def delete_employee(emp_id: str, db: Session = Depends(get_db)):
    emp = db.query(models.Employee).filter(models.Employee.EMP_ID == emp_id).first()
    if not emp:
        raise HTTPException(status_code=404, detail="Employee not found")
    
    db.query(models.Points).filter(models.Points.EMP_ID == emp_id).delete()
    
    db.delete(emp)
    db.commit()
    return {"message": "Deleted successfully"}

@app.get("/admin/redemptions")
def get_all_redemptions(status: str = None, db: Session = Depends(get_db)):
    query = db.query(models.Redeem).order_by(models.Redeem.REDEEM_DATE.desc())
    if status:
        query = query.filter(models.Redeem.STATUS == status)
    
    redemptions = query.all()
    results = []
    for r in redemptions:
        emp = db.query(models.Employee).filter(models.Employee.EMP_ID == r.EMP_ID).first()
        prize = db.query(models.Prize).filter(models.Prize.PRIZE_ID == r.PRIZE_ID).first()
        
        results.append({
            "redeemId": r.REDEEM_ID,
            "empId": r.EMP_ID,
            "empName": emp.EMP_NAME_EN if emp else "Unknown",
            "prizeName": prize.PRIZE_NAME if prize else "Unknown",
            "pointCost": prize.PRIZE_POINTS if prize else 0,
            "redeemDate": r.REDEEM_DATE,
            "status": r.STATUS
        })
    return results

@app.put("/admin/redemptions/{redeem_id}/status")
async def update_redemption_status(redeem_id: str, status: str, db: Session = Depends(get_db)):
    redeem = db.query(models.Redeem).filter(models.Redeem.REDEEM_ID == redeem_id).first()
    if not redeem:
        raise HTTPException(status_code=404, detail="Not found")
    
    redeem.STATUS = status

    # Logic คืนแต้มกรณี Cancel (คงเดิม)
    if status == 'Cancelled':
        prize = db.query(models.Prize).filter(models.Prize.PRIZE_ID == redeem.PRIZE_ID).first()
        emp_points = db.query(models.Points).filter(models.Points.EMP_ID == redeem.EMP_ID).first()
        
        if prize and emp_points:
            prize.STOCK += 1
            emp_points.TOTAL_POINTS += prize.PRIZE_POINTS
            
            new_txn = models.PointTransaction(
                TXN_ID=generate_id("TXN", 10),
                EMP_ID=redeem.EMP_ID,
                TXN_TYPE="Refund",
                REF_TYPE="REDEEM",
                REF_ID=redeem_id,
                POINTS=prize.PRIZE_POINTS,
                TXN_DATE=datetime.now()
            )
            db.add(new_txn)

    prize = db.query(models.Prize).filter(models.Prize.PRIZE_ID == redeem.PRIZE_ID).first()
    prize_name = prize.PRIZE_NAME if prize else "ของรางวัล"

    notif_title = ""
    notif_msg = ""
    notif_type = "Reward"

    if status == 'Completed':
        notif_title = "คำขอแลกรางวัลสำเร็จ ✅"
        notif_msg = f"คำขอแลก '{prize_name}' ของคุณได้รับการอนุมัติแล้ว"
    elif status == 'Cancelled':
        notif_title = "คำขอแลกรางวัลถูกยกเลิก ❌"
        notif_msg = f"คำขอแลก '{prize_name}' ถูกยกเลิก ระบบได้คืนคะแนนให้คุณแล้ว"
        notif_type = "Alert"
    
    if notif_title:
        # 1. สร้าง Notification ลง DB (คงเดิม)
        create_notification_internal(
            db,
            emp_id=redeem.EMP_ID, 
            title=notif_title,
            message=notif_msg,
            notif_type=notif_type,
            ref_id=redeem_id,
            route_path="/reward_history"
        )
        
        # [แก้ไข] 2. เพิ่มบรรทัดนี้เพื่อยิง Socket หาพนักงานคนนั้น
        await manager.send_personal_message("REFRESH_NOTIFICATIONS", redeem.EMP_ID)
        
    db.commit()
    return {"message": f"Status updated to {status}"}


@app.get("/admin/stats")
def get_admin_stats(db: Session = Depends(get_db)):
    total_emp = db.query(models.Employee).count()
    pending_req = db.query(models.Redeem).filter(models.Redeem.STATUS == 'Pending').count()
    total_rewards = db.query(models.Prize).filter(models.Prize.STATUS == 'Available').count()
    total_act = db.query(models.Activity).count()
    
    return {
        "totalEmployees": total_emp,
        "pendingRequests": pending_req,
        "totalRewards": total_rewards,
        "totalActivities": total_act
    }

@app.post("/admin/policy/run_expiry_batch")
def run_expiry_batch(admin_id: str, db: Session = Depends(get_db)):
    company_id = get_admin_company_id_and_check(admin_id, db)
    
    today = date.today()
    
    expired_users = db.query(models.Points).join(models.Employee).filter(
        models.Employee.COMPANY_ID == company_id,
        models.Points.EXPIRY_DATE < today, 
        models.Points.TOTAL_POINTS > 0
    ).all()
    
    if not expired_users:
        return {"message": "No expired points found today.", "processed_users": 0, "total_points_removed": 0}

    expired_count = 0
    total_points_cut = 0

    try:
        for user_point in expired_users:
            old_points = user_point.TOTAL_POINTS
            emp_id = user_point.EMP_ID
            
            txn_id = generate_id("TXN", 10)
            expiry_txn = models.PointTransaction(
                TXN_ID=txn_id,
                EMP_ID=emp_id,
                TXN_TYPE="Expire",
                REF_TYPE="SYSTEM",
                REF_ID=f"EXP-{today}",
                POINTS=-old_points,
                TXN_DATE=datetime.now()
            )
            db.add(expiry_txn)
            
            user_point.TOTAL_POINTS = 0

            expired_count += 1
            total_points_cut += old_points
        
        db.commit()
        
        print(f"✅ Batch Expiry Complete: {expired_count} users, {total_points_cut} points removed.")
        return {
            "message": "Expiry batch executed successfully",
            "processed_users": expired_count,
            "total_points_removed": total_points_cut
        }

    except Exception as e:
        db.rollback()
        print(f"❌ Expiry Batch Failed: {e}")
        raise HTTPException(status_code=500, detail=f"Batch failed: {str(e)}")

@app.get("/admin/policy/points")
def get_point_policy(admin_id: str, db: Session = Depends(get_db)):
    company_id = get_admin_company_id_and_check(admin_id, db)

    policy = db.query(models.PointPolicy).filter(
        models.PointPolicy.COMPANY_ID == company_id
    ).first()

    if not policy:
        return {
            "policy_id": None,
            "policy_name": "Annual Expiry Policy",
            "start_date": date(date.today().year, 1, 1).isoformat(),
            "end_date": date(date.today().year, 12, 31).isoformat(),
            "description": "The current period ends on December 31st.",
        }

    return {
        "policy_id": policy.POLICY_ID,
        "policy_name": policy.POLICY_NAME,
        "start_date": policy.START_PERIOD.isoformat(),
        "end_date": policy.END_PERIOD.isoformat(),
        "description": policy.DESCRIPTION
    }

@app.post("/admin/policy/points")
def set_point_policy(admin_id: str, req: PointPolicyRequest, db: Session = Depends(get_db)):
    company_id = get_admin_company_id_and_check(admin_id, db)
    
    policy = db.query(models.PointPolicy).filter(
        models.PointPolicy.COMPANY_ID == company_id
    ).first()
    
    if not policy:
        policy_id = generate_id("POL", 5)
        policy = models.PointPolicy(
            POLICY_ID=policy_id,
            COMPANY_ID=company_id,
            POLICY_NAME=req.policy_name,
            START_PERIOD=req.start_date,
            END_PERIOD=req.end_date,
            DESCRIPTION=req.description
        )
        db.add(policy)
    else:
        policy.POLICY_NAME = req.policy_name
        policy.START_PERIOD = req.start_date
        policy.END_PERIOD = req.end_date
        policy.DESCRIPTION = req.description
        
    try:
        db.commit()
        
        employee_ids = db.query(models.Employee.EMP_ID).filter(
            models.Employee.COMPANY_ID == company_id
        ).all()
        
        for emp_id_tuple in employee_ids:
            emp_id = emp_id_tuple[0]
            points_record = db.query(models.Points).filter(models.Points.EMP_ID == emp_id).first()
            if points_record:
                points_record.EXPIRY_DATE = req.end_date
            else:
                new_points = models.Points(
                    EMP_ID=emp_id,
                    TOTAL_POINTS=0,
                    EXPIRY_DATE=req.end_date
                )
                db.add(new_points)

        db.commit()

        return {"message": "Point policy and employee expiry dates updated successfully"}

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.post("/admin/rewards")
def create_reward(req: PrizeCreateRequest, admin_id: str, db: Session = Depends(get_db)):
    company_id = get_admin_company_id_and_check(admin_id, db)
    
    new_id = generate_id("P", 5)
    new_prize = models.Prize(
        PRIZE_ID=new_id,
        COMPANY_ID=company_id,
        PRIZE_NAME=req.name,
        PRIZE_POINTS=req.point_cost,
        PRIZE_DESCRIPTION=req.description,
        PRIZE_IMAGES=json.dumps(req.images),
        STOCK=req.stock,
        STATUS='Available',
        MANAGED_BY=admin_id,
        PICKUP_INSTRUCTION=req.pickup_instruction,
        PRIZE_TYPE=req.prize_type
    )
    db.add(new_prize)
    db.commit()
    return {"message": "Reward created successfully", "id": new_id}

@app.put("/admin/rewards/{prize_id}")
def update_reward(prize_id: str, req: PrizeCreateRequest, admin_id: str, db: Session = Depends(get_db)):
    company_id = get_admin_company_id_and_check(admin_id, db)
    
    prize = db.query(models.Prize).filter(models.Prize.PRIZE_ID == prize_id).first()
    if not prize:
        raise HTTPException(status_code=404, detail="Reward not found")
        
    prize.PRIZE_NAME = req.name
    prize.PRIZE_POINTS = req.point_cost
    prize.PRIZE_DESCRIPTION = req.description
    prize.PRIZE_IMAGES = json.dumps(req.images)
    prize.STOCK = req.stock
    prize.PRIZE_TYPE = req.prize_type
    prize.PICKUP_INSTRUCTION = req.pickup_instruction
    
    db.commit()
    return {"message": "Reward updated successfully"}

@app.delete("/admin/rewards/{prize_id}")
def delete_reward(prize_id: str, admin_id: str, db: Session = Depends(get_db)):
    get_admin_company_id_and_check(admin_id, db)
    
    prize = db.query(models.Prize).filter(models.Prize.PRIZE_ID == prize_id).first()
    if not prize:
        raise HTTPException(status_code=404, detail="Reward not found")
    
    prize.STATUS = 'Discontinued' 
    db.commit()
    return {"message": "Reward discontinued"}

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, emp_id: str = Query(None)):
    if not emp_id:
        await websocket.close()
        return
    await manager.connect(websocket, emp_id)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(emp_id)

@app.post("/admin/rewards/scan_pickup")
def process_pickup_scan(req: PrizePickupRequest, db: Session = Depends(get_db)):
    # 1. Check Admin Permission
    get_admin_company_id_and_check(req.admin_id, db)

    # 2. Find the Redemption Record
    redeem = db.query(models.Redeem).filter(models.Redeem.REDEEM_ID == req.redeem_id).first()

    if not redeem:
        raise HTTPException(status_code=404, detail="Redemption ID not found.")
    
    if redeem.STATUS == 'Completed' or redeem.STATUS == 'Received':
        raise HTTPException(status_code=400, detail="Reward already picked up.")

    if redeem.STATUS != 'Pending':
        raise HTTPException(status_code=400, detail=f"Cannot process status: {redeem.STATUS}")

    # 3. Update Status to Completed (Received)
    redeem.STATUS = 'Completed'
    redeem.APPROVED_BY = req.admin_id
    redeem.RECEIVED_DATE = date.today()
    
    db.commit()
    
    # 4. Notify everyone to refresh UI
    manager.broadcast("REFRESH_REWARDS")
    
    return {
        "message": "Pickup confirmed and status updated to Completed.",
        "redeem_id": req.redeem_id,
        "prize_name": db.query(models.Prize).filter(models.Prize.PRIZE_ID == redeem.PRIZE_ID).first().PRIZE_NAME
    }


@app.put("/admin/employees/{emp_id}")
def update_employee(emp_id: str, req: EmployeeUpdateRequest, db: Session = Depends(get_db)):
    # 1. หาพนักงาน
    emp = db.query(models.Employee).filter(models.Employee.EMP_ID == emp_id).first()
    if not emp:
        raise HTTPException(status_code=404, detail="Employee not found")
    
    # 2. จัดการแผนก (ใช้ Logic เดียวกับ Activity เพื่อหา/สร้างแผนก)
    # เราต้องหา Company ID ของพนักงานคนนี้เพื่อสร้างแผนกในบริษัทเดียวกัน
    company_id = emp.COMPANY_ID
    final_dep_id = resolve_department_id(db, req.department_id, company_id) # Reuse function เดิม

    # 3. อัปเดตข้อมูล
    emp.EMP_TITLE_EN = req.title
    emp.EMP_NAME_EN = req.name
    emp.EMP_PHONE = req.phone
    emp.EMP_EMAIL = req.email
    emp.DEP_ID = final_dep_id
    emp.EMP_POSITION = req.position
    emp.EMP_ROLE = req.role
    emp.EMP_STATUS = req.status
    
    try:
        emp.EMP_STARTDATE = datetime.strptime(req.start_date, "%Y-%m-%d").date()
    except:
        pass # ถ้าวันที่ผิด ไม่ต้องแก้

    try:
        db.commit()
        return {"message": "Employee updated successfully"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Update failed: {str(e)}")



# [API] ดึงรายการแจ้งเตือน
@app.get("/notifications/{emp_id}", response_model=list[NotificationResponse])
def get_my_notifications(
    emp_id: str, 
    role: str = "Employee", # <--- [NEW] รับ Query Param (?role=Admin)
    db: Session = Depends(get_db)
):
    # ดึง 50 รายการล่าสุด เรียงจากใหม่ไปเก่า
    notifs = db.query(models.Notification)\
        .filter(models.Notification.EMP_ID == emp_id)\
        .filter(models.Notification.TARGET_ROLE == role)\
        .order_by(models.Notification.CREATED_AT.desc())\
        .limit(50)\
        .all()
    
    # Map ข้อมูลให้ตรงกับ Pydantic Model
    results = []
    for n in notifs:
        results.append({
            "notifId": n.NOTIF_ID,
            "title": n.TITLE,
            "message": n.MESSAGE,
            "type": n.NOTIF_TYPE,
            "isRead": n.IS_READ,
            "createdAt": n.CREATED_AT,
            "routePath": n.ROUTE_PATH,
            "refId": n.REF_ID
        })
    return results

# [API] อ่านแจ้งเตือน
@app.put("/notifications/{notif_id}/read")
def mark_notification_read(notif_id: str, db: Session = Depends(get_db)):
    notif = db.query(models.Notification).filter(models.Notification.NOTIF_ID == notif_id).first()
    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")
    
    notif.IS_READ = True
    db.commit()
    return {"message": "Marked as read"}


@app.get("/notifications/{emp_id}/unread")
def get_unread_count(
    emp_id: str, 
    role: str = "Employee", 
    db: Session = Depends(get_db)
):
    # นับจำนวนแจ้งเตือนของ Role นั้นๆ ที่ยังไม่ได้อ่าน (IS_READ = False)
    count = db.query(models.Notification)\
        .filter(models.Notification.EMP_ID == emp_id)\
        .filter(models.Notification.TARGET_ROLE == role)\
        .filter(models.Notification.IS_READ == False)\
        .count()
    
    return {"count": count}


@app.put("/notifications/{emp_id}/read-all")
def mark_all_notifications_read(emp_id: str, db: Session = Depends(get_db)):
    # อัปเดตทุกรายการของ emp_id นี้ ที่ยังไม่อ่าน (IS_READ = False) -> ให้เป็น True
    db.query(models.Notification).filter(
        models.Notification.EMP_ID == emp_id,
        models.Notification.IS_READ == False
    ).update({models.Notification.IS_READ: True}, synchronize_session=False)
    
    db.commit()
    return {"message": "All marked as read"}


@app.post("/admin/announcement")
async def create_system_announcement(req: AnnouncementRequest, db: Session = Depends(get_db)):
    # 1. หาพนักงานเป้าหมาย (ในที่นี้เอาทุกคนที่ Active)
    targets = db.query(models.Employee).filter(models.Employee.EMP_STATUS == 'Active').all()
    
    count = 0
    for emp in targets:
        # สร้างแจ้งเตือนลง DB
        create_notification_internal(
            db,
            emp_id=emp.EMP_ID,
            title=f"📢 {req.title}", # ใส่ไอคอนประกาศ
            message=req.message,
            notif_type="System",
            target_role="Employee",
            route_path=None # ส่วนใหญ่ประกาศจะไม่มีหน้าให้กดไปต่อ หรืออาจจะไปหน้า Profile
        )
        count += 1
    
    db.commit()
    
    # 2. ยิง Real-time Broadcast หาทุกคนที่ต่อ Socket อยู่
    await manager.broadcast("REFRESH_NOTIFICATIONS")
    
    return {"message": f"Announcement sent to {count} employees"}



@app.get("/titles")
def get_titles(db: Session = Depends(get_db)):
    # ดึงข้อมูลจากคอลัมน์ EMP_TITLE_EN แบบไม่ซ้ำกัน (Distinct)
    titles = db.query(models.Employee.EMP_TITLE_EN).distinct().all()
    # กรองค่า None หรือค่าว่างออก แล้วคืนกลับเป็น List
    return [t[0] for t in titles if t[0] and t[0].strip()]


@app.post("/admin/employees")
def create_employee(req: EmployeeCreateRequest, admin_id: str = Query(...), db: Session = Depends(get_db)):
    # Check Permission
    get_admin_company_id_and_check(admin_id, db)
    
    # Check Email Duplicate
    if db.query(models.Employee).filter(models.Employee.EMP_EMAIL == req.email).first():
        raise HTTPException(status_code=400, detail="Email already exists")

    try:
        # Generate ID
        new_id = generate_id("E")
        while db.query(models.Employee).filter(models.Employee.EMP_ID == new_id).first():
            new_id = generate_id("E")
            
        # Resolve Department
        admin = db.query(models.Employee).filter(models.Employee.EMP_ID == admin_id).first()
        final_dep_id = resolve_department_id(db, req.department_id, admin.COMPANY_ID)

        # Create Employee
        new_emp = models.Employee(
            EMP_ID=new_id,
            COMPANY_ID=admin.COMPANY_ID,
            EMP_TITLE_EN=req.title,
            EMP_NAME_EN=req.name,
            EMP_POSITION=req.position,
            DEP_ID=final_dep_id,
            EMP_PHONE=req.phone,
            EMP_EMAIL=req.email,
            EMP_PASSWORD=get_password_hash(req.password),
            EMP_STARTDATE=parse_date_str(req.start_date),
            EMP_STATUS=req.status,
            EMP_ROLE=req.role
        )
        db.add(new_emp)
        
        # If Organizer, create profile
        if req.role.lower() == 'organizer':
             new_org = models.Organizer(
                ORG_ID=generate_id("O"),
                EMP_ID=new_id,
                ORG_CONTACT_INFO=req.phone,
                ORG_UNIT=req.department_id, # Use raw name as unit
                ORG_NOTE="Manual Created"
            )
             db.add(new_org)

        db.commit()
        return {"message": "Employee created successfully", "id": new_id}

    except Exception as e:
        db.rollback()
        print(f"Create Emp Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))