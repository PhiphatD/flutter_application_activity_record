from fastapi import FastAPI, HTTPException, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel
from passlib.context import CryptContext
from datetime import date, datetime
import models
from database import engine, get_db
import random
import string
import smtplib 
from email.mime.text import MIMEText 
from email.mime.multipart import MIMEMultipart 
from datetime import time
# --- CSV Upload ---
import csv
import codecs
from fastapi import File, UploadFile, Form
from datetime import timedelta, datetime
import json
from fastapi import WebSocket, WebSocketDisconnect

# สร้างตารางใน DB อัตโนมัติ (ถ้ายังไม่มี)
models.Base.metadata.create_all(bind=engine)

app = FastAPI()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# --- Schemas (ตัวกำหนดรูปแบบข้อมูลที่รับส่ง) ---

class PrizeResponse(BaseModel):
    id: str
    name: str
    pointCost: int
    description: str
    image: str | None = None
    stock: int
    category: str = "General"  # Default category for now
    status: str
    
    class Config:
        from_attributes = True

class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: str):
        # ส่งข้อความหาทุกเครื่องที่ต่ออยู่
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except:
                pass

manager = ConnectionManager()

class CancelRedeemRequest(BaseModel):
    emp_id: str
    redeem_id: str

class RedeemRequest(BaseModel):
    emp_id: str
    prize_id: str

class ActivityRegisterRequest(BaseModel):
    emp_id: str
    session_id: str

class PrizeResponse(BaseModel):
    id: str
    name: str
    pointCost: int
    description: str
    image: str | None = None
    stock: int
    category: str = "General" # Default category for now
    status: str
    prizeType: str = "Physical"

    class Config:
        from_attributes = True

class MyRedemptionResponse(BaseModel):
    redeemId: str
    prizeName: str
    pointCost: int
    redeemDate: datetime
    status: str
    image: str | None = None
    pickupInstruction: str | None = "Contact HR"
    class Config:
        from_attributes = True

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
    taxId: str          # New
    address: str        # New
    businessType: str
    
    # Admin Info
    adminTitle: str     # New
    adminFullName: str
    adminEmail: str
    adminPhone: str
    adminPassword: str
    adminStartDate: str

class ActivityResponse(BaseModel):
    actId: str          # แก้เป็น String ให้ตรงกับ DB
    orgId: str          # แก้เป็น String
    organizerName: str
    actType: str
    isCompulsory: int
    point: int
    name: str
    currentParticipants: int
    maxParticipants: int
    status: str
    location: str = "-" # เพิ่ม location
    activityDate: date | None = None
    startTime: str | None = "-" 
    endTime: str | None = "-"
    isRegistered: bool = False
    class Config:
        orm_mode = True

# [NEW] Schema สำหรับ Session ในหน้า Detail
class ActivitySessionResponse(BaseModel):
    sessionId: str
    date: date
    startTime: time
    endTime: time
    location: str
    status: str
    class Config:
        orm_mode = True

# [NEW] Schema สำหรับหน้า Detail (ข้อมูลครบ)
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
    actImage: str | None = None # [NEW] เพิ่มตัวนี้
    agenda: str | None = None # [NEW]
    isFavorite: bool = False
    isRegistered: bool = False # [NEW]
    sessions: list[ActivitySessionResponse]

    class Config:
        orm_mode = True

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
    ACT_IMAGE: str | None = None  # รับ URL ของรูป
    ACT_AGENDA: str | None = None # รับ JSON String ของ Agenda

class OrganizerData(BaseModel):
    ORG_NAME: str
    ORG_CONTACT_INFO: str

class SessionData(BaseModel):
    SESSION_DATE: str # รับเป็น String ISO Format
    START_TIME: str   # HH:MM
    END_TIME: str     # HH:MM
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

# [NEW] Schema สำหรับตอบกลับ My Activities (Upcoming)
@app.get("/my-registrations/{emp_id}", response_model=list[MyActivityResponse])
def get_my_registrations(emp_id: str, db: Session = Depends(get_db)):
    today = date.today()
    
    employee = db.query(models.Employee).filter(models.Employee.EMP_ID == emp_id).first()
    if not employee:
        raise HTTPException(status_code=404, detail="Employee not found")
    
    emp_dept_name = employee.department.DEP_NAME if employee.department else ""
    emp_position = employee.EMP_POSITION

    output = []
    
    # --- Part A: กิจกรรมที่ลงทะเบียนจริง ---
    regs = db.query(models.Registration).filter(models.Registration.EMP_ID == emp_id).all()
    registered_session_ids = set()

    for r in regs:
        registered_session_ids.add(r.SESSION_ID)
        
        sess = db.query(models.ActivitySession).filter(models.ActivitySession.SESSION_ID == r.SESSION_ID).first()
        if not sess: continue
        
        act = db.query(models.Activity).filter(models.Activity.ACT_ID == sess.ACT_ID).first()
        if not act: continue
        
        checkin = db.query(models.CheckIn).filter(
            models.CheckIn.EMP_ID == emp_id, 
            models.CheckIn.SESSION_ID == sess.SESSION_ID
        ).first()
        
        status = "Upcoming"
        if checkin:
            status = "Joined"
        elif sess.SESSION_DATE < today:
            status = "Missed"
        
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
            # [NEW] เพิ่ม 2 ค่านี้
            "isCompulsory": act.ACT_ISCOMPULSORY == 1, 
            "point": act.ACT_POINT
        })

    # --- Part B: กิจกรรมบังคับ (Auto-Inject) ---
    compulsory_acts = db.query(models.Activity).join(models.ActivitySession).filter(
        models.Activity.ACT_ISCOMPULSORY == True
    ).distinct().all()

    for act in compulsory_acts:
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
                    if emp_dept_name in criteria.get('departments', []):
                        is_target = True
                    if not is_target and emp_position in criteria.get('positions', []):
                        is_target = True
            except:
                is_target = False

        if is_target:
            target_sessions = [s for s in act.sessions if s.SESSION_DATE >= today]
            if not target_sessions: continue 

            target_session = sorted(target_sessions, key=lambda x: (x.SESSION_DATE, x.START_TIME))[0]

            if target_session.SESSION_ID in registered_session_ids:
                continue

            output.append({
                "actId": act.ACT_ID,
                "actType": act.ACT_TYPE,
                "name": act.ACT_NAME,
                "location": target_session.LOCATION,
                "activityDate": target_session.SESSION_DATE,
                "startTime": target_session.START_TIME.strftime("%H:%M"),
                "endTime": target_session.END_TIME.strftime("%H:%M"),
                "status": "Upcoming", 
                "sessionId": target_session.SESSION_ID,
                # [NEW] เพิ่ม 2 ค่านี้ (บังคับต้องเป็น True)
                "isCompulsory": True,
                "point": act.ACT_POINT
            })
    
    output.sort(key=lambda x: x['activityDate'], reverse=True)
    return output

# [NEW] Schema สำหรับข้อมูลผู้เข้าร่วม (Participant)
class ParticipantResponse(BaseModel):
    empId: str
    title: str | None = None 
    name: str
    department: str
    status: str         # "Registered" หรือ "Joined"
    checkInTime: str    # เวลาที่เช็คอิน (ถ้ามี)
    
    class Config:
        orm_mode = True

class CheckInRequest(BaseModel):
    emp_id: str
    act_id: str        # หรือ session_id ก็ได้ แต่เพื่อความง่ายใช้ act_id ก่อน แล้วระบบหา session ที่ใกล้สุดเอง
    scanned_by: str    # ระบุว่าใครเป็นคนสแกน ('organizer' หรือ 'self')
    location_lat: float | None = None # เผื่ออนาคตเช็คพิกัด
    location_long: float | None = None
    
# --- Helper Functions ---
def _bcrypt_safe(password: str) -> str:
    # ตัดรหัสผ่านให้ไม่เกิน 72 bytes เพื่อป้องกัน bcrypt error
    pw_bytes = password.encode('utf-8') if isinstance(password, str) else password
    pw_bytes = pw_bytes[:72]
    return pw_bytes.decode('utf-8', errors='ignore')

def get_password_hash(password):
    return pwd_context.hash(_bcrypt_safe(password))

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(_bcrypt_safe(plain_password), hashed_password)

def generate_id(prefix, length=5):
    # สร้าง ID สุ่ม เช่น C1234, E5678
    return prefix + ''.join(random.choices(string.digits, k=length-1))

def send_otp_email(to_email: str, otp_code: str):
    # --- ตั้งค่าอีเมลคนส่ง ---
    sender_email = "nut98765431@gmail.com"      # <--- ใส่ Gmail ของคุณที่นี่
    sender_password = "vamo wowf mbzm lkkz"    # <--- ใส่ App Password 16 หลักที่ได้มา (ไม่ใช่รหัสผ่านเข้าเมล!)

    # ตั้งค่าเนื้อหาอีเมล
    subject = "รหัส OTP สำหรับรีเซ็ตรหัสผ่าน - Activity App"
    body = f"""
    สวัสดี,
    
    คุณได้ทำการร้องขอรหัสผ่านใหม่
    รหัส OTP ของคุณคือ: {otp_code}
    
    หากคุณไม่ได้ทำรายการนี้ โปรดเพิกเฉยต่ออีเมลฉบับนี้
    """

    # สร้าง Object อีเมล
    msg = MIMEMultipart()
    msg['From'] = sender_email
    msg['To'] = to_email
    msg['Subject'] = subject
    msg.attach(MIMEText(body, 'plain'))

    try:
        # เชื่อมต่อกับ Gmail SMTP Server
        server = smtplib.SMTP('smtp.gmail.com', 587)
        server.starttls() # เข้ารหัสการเชื่อมต่อ
        server.login(sender_email, sender_password)
        text = msg.as_string()
        server.sendmail(sender_email, to_email, text)
        server.quit()
        print(f"✅ Email sent to {to_email}")
    except Exception as e:
        print(f"❌ Failed to send email: {e}")
        raise Exception("ไม่สามารถส่งอีเมลได้ กรุณาตรวจสอบระบบ")

# [NEW] ฟังก์ชันช่วยแปลงวันที่ให้รองรับหลายรูปแบบ  
def parse_date_str(date_str: str) -> date:
    if not date_str or not date_str.strip():
        return date.today()
    
    # ลบช่องว่างหัวท้าย
    d = date_str.strip()
    
    # รูปแบบวันที่ที่รองรับ
    formats = [
        '%Y-%m-%d', # 2025-11-19 (Standard Database)
        '%d/%m/%Y', # 19/11/2025 (Thai/UK format)
        '%d-%m-%Y', # 19-11-2025
        '%Y/%m/%d'  # 2025/11/19
    ]
    
    for fmt in formats:
        try:
            return datetime.strptime(d, fmt).date()
        except ValueError:
            continue
            
    # ถ้าแปลงไม่ได้เลย ให้ใช้วันปัจจุบันแทน (หรือจะ raise Error ก็ได้)
    return date.today()

def parse_time_safe(t_str: str) -> time:
    if not t_str:
        return time(9, 0)
    t_str = t_str.strip()
    # รูปแบบเวลาที่รองรับ: 24 ชม., มีวินาที, หรือ AM/PM
    formats = ["%H:%M", "%H:%M:%S", "%I:%M %p"] 
    for fmt in formats:
        try:
            return datetime.strptime(t_str, fmt).time()
        except ValueError:
            continue
    # Default fallback ถ้าแปลงไม่ได้
    return time(9, 0)

# --- API Endpoints ---

# ในไฟล์ main.py ส่วน Endpoint /login

@app.post("/login")
def login(req: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(models.Employee).filter(models.Employee.EMP_EMAIL == req.email).first()
    
    if not user or not verify_password(req.password, user.EMP_PASSWORD):
        raise HTTPException(status_code=400, detail="อีเมลหรือรหัสผ่านไม่ถูกต้อง")
    
    # [NEW] หา org_id ถ้ามี
    org_id = None
    if user.organizer_profile:
        org_id = user.organizer_profile.ORG_ID

    return {
        "message": "Login successful",
        "role": user.EMP_ROLE,
        "emp_id": user.EMP_ID,
        "company_id": user.COMPANY_ID,
        "name": user.EMP_NAME_EN,
        "org_id": org_id # [ADDED] ส่งค่านี้กลับไป
    }

@app.post("/register_organization")
def register_org(req: RegisterRequest, db: Session = Depends(get_db)):
    # 1. เช็คก่อนว่า Email ซ้ำไหม
    existing_user = db.query(models.Employee).filter(models.Employee.EMP_EMAIL == req.adminEmail).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="อีเมลนี้ถูกใช้งานแล้ว")

    try:
        # --- เริ่ม Transaction ---
        
        # 2. สร้าง Company
        new_company_id = generate_id("C")
        # loop เช็ค ID ซ้ำ
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

        # 3. สร้าง Department แรก (Headquarters)
        new_dep_id = generate_id("D")
        while db.query(models.Department).filter(models.Department.DEP_ID == new_dep_id).first():
             new_dep_id = generate_id("D")

        new_department = models.Department(
            DEP_ID=new_dep_id,
            COMPANY_ID=new_company_id, # ผูกกับบริษัทที่เพิ่งสร้าง
            DEP_NAME="Headquarters"    # แผนกเริ่มต้น
        )
        db.add(new_department)

        # 4. สร้าง Employee (Admin)
        new_emp_id = generate_id("E")
        while db.query(models.Employee).filter(models.Employee.EMP_ID == new_emp_id).first():
            new_emp_id = generate_id("E")

        hashed_pw = get_password_hash(req.adminPassword)
        try:
            # แปลงจาก YYYY-MM-DD
            start_date_obj = date.fromisoformat(req.adminStartDate)
        except (ValueError, TypeError):
            # ถ้าแปลงไม่ได้ หรือส่งมาผิด ให้ใช้วันปัจจุบัน
            start_date_obj = date.today()
        # ------------------------------------------------------
        new_admin = models.Employee(
            EMP_ID=new_emp_id,
            COMPANY_ID=new_company_id, # ผูกกับบริษัท
            EMP_TITLE_EN=req.adminTitle, # คำนำหน้า
            EMP_NAME_EN=req.adminFullName, # เบื้องต้นใช้ชื่อเดียวกันไปก่อน
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

        # 5. ✅ Commit ทีเดียวตอนจบ
        db.commit()
        
        return {
            "message": "ลงทะเบียนองค์กรสำเร็จ", 
            "emp_id": new_emp_id,
            "company_id": new_company_id
        }

    except Exception as e:
        # 6. 🛑 ถ้ามีอะไรพัง ให้ยกเลิกทั้งหมด (Rollback)
        db.rollback()
        print(f"Error Registering: {e}")
        raise HTTPException(status_code=500, detail=f"เกิดข้อผิดพลาด: {str(e)}")

# --- API Endpoints Reset Password  ---

# 1. ขอ OTP
@app.post("/forgot-password")
def forgot_password(req: ForgotPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(models.Employee).filter(models.Employee.EMP_EMAIL == req.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="ไม่พบอีเมลนี้ในระบบ")
    
    # สร้าง OTP 6 หลัก
    otp = ''.join(random.choices(string.digits, k=6))
    
    # บันทึกลง DB
    user.OTP_CODE = otp
    db.commit()
    
    # *** เปลี่ยนจาก Print เป็นส่งอีเมลจริง ***
    try:
        send_otp_email(req.email, otp) # เรียกฟังก์ชันส่งอีเมล
    except Exception as e:
        raise HTTPException(status_code=500, detail="เกิดข้อผิดพลาดในการส่งอีเมล")
    
    return {"message": "ส่งรหัส OTP ไปยังอีเมลเรียบร้อยแล้ว"}

# 2. ตรวจสอบ OTP
@app.post("/verify-otp")
def verify_otp(req: VerifyOtpRequest, db: Session = Depends(get_db)):
    user = db.query(models.Employee).filter(models.Employee.EMP_EMAIL == req.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    if user.OTP_CODE != req.otp:
        raise HTTPException(status_code=400, detail="รหัส OTP ไม่ถูกต้อง")
        
    return {"message": "OTP ถูกต้อง"}

# 3. เปลี่ยนรหัสผ่านใหม่
@app.post("/reset-password")
def reset_password(req: ResetPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(models.Employee).filter(models.Employee.EMP_EMAIL == req.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Hash รหัสผ่านใหม่
    hashed_pw = get_password_hash(req.newPassword)
    
    # อัปเดตข้อมูล
    user.EMP_PASSWORD = hashed_pw
    user.OTP_CODE = None # เคลียร์ OTP ทิ้งเมื่อใช้แล้ว
    db.commit()
    
    return {"message": "เปลี่ยนรหัสผ่านสำเร็จ"}

# --- API Endpoint ใหม่สำหรับดึงข้อมูล Profile ---
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

    # [NEW] ดึงคะแนนจากตาราง Points
    current_points = 0
    if user.points:
        current_points = user.points.TOTAL_POINTS

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
        "TOTAL_POINTS": current_points # [ADDED] ส่งคะแนนจริงกลับไป
    }

# --- API สำหรับ Import พนักงานจาก CSV ---

@app.post("/import_employees")
async def import_employees(
    admin_id: str = Form(...),      
    file: UploadFile = File(...),   
    db: Session = Depends(get_db)
):
    # 1. หา Company ของ Admin คนนี้
    admin_user = db.query(models.Employee).filter(models.Employee.EMP_ID == admin_id).first()
    if not admin_user:
        raise HTTPException(status_code=404, detail="Admin not found")
    
    current_company_id = admin_user.COMPANY_ID
    print(f"📥 Importing for Company ID: {current_company_id}")

    try:
        # 2. อ่านไฟล์ CSV
        # ใช้ codecs.iterdecode เพื่อรองรับภาษาไทย (utf-8-sig เผื่อมี BOM จาก Excel)
        csvReader = csv.DictReader(codecs.iterdecode(file.file, 'utf-8-sig'))
        
        success_count = 0
        errors = []

        for row in csvReader:
            try:
                # --- A. จัดการแผนก (Department) ---
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

                # --- B. ตรวจสอบ Email ซ้ำ ---
                email = row.get('Email', '').strip()
                if db.query(models.Employee).filter(models.Employee.EMP_EMAIL == email).first():
                    errors.append(f"Email {email} already exists.")
                    continue

                # --- C. เตรียมข้อมูล ---
                # [UPDATED] แปลง Role ให้ยืดหยุ่นขึ้น
                raw_role = row.get('Role', 'employee').strip().lower()
                final_role = 'employee'
                if raw_role in ['organizer', 'organiser', 'admin']: # รองรับทั้ง z และ s
                    final_role = 'organizer' if raw_role != 'admin' else 'admin'

                # [UPDATED] แปลงวันที่ด้วยฟังก์ชันใหม่
                start_date_val = parse_date_str(row.get('StartDate', ''))

                new_emp_id = generate_id("E")
                while db.query(models.Employee).filter(models.Employee.EMP_ID == new_emp_id).first():
                    new_emp_id = generate_id("E")

                new_emp = models.Employee(
                    EMP_ID=new_emp_id,
                    COMPANY_ID=current_company_id, 
                    EMP_TITLE_EN=row.get('Title', ''),
                    EMP_TITLE_TH=row.get('Title', ''), 
                    EMP_NAME_EN=row.get('Name', ''),
                    EMP_NAME_TH=row.get('Name', ''),   
                    EMP_POSITION=row.get('Position', 'Staff'),
                    DEP_ID=department.DEP_ID,          
                    EMP_PHONE=row.get('Phone', ''),
                    EMP_EMAIL=email,
                    EMP_PASSWORD=get_password_hash(row.get('Password', '123456')),
                    EMP_STARTDATE=start_date_val, # ใช้วันที่ที่แปลงแล้ว
                    EMP_STATUS='Active',
                    EMP_ROLE=final_role, # ใช้ Role ที่ผ่านการจัดรูปแบบแล้ว
                    OTP_CODE=None
                )
                db.add(new_emp)

                # --- D. ถ้าเป็น Organizer ให้เพิ่มลงตาราง Organizer ด้วย ---
                if final_role == 'organizer':
                    new_org_id = generate_id("ORG") 
                    
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

# [UPDATED] API ดึงข้อมูลกิจกรรม (เพิ่ม mode การกรอง)
# mode: 'all' (Organizer - ดูทั้งหมด), 'future' (Employee - ดูเฉพาะที่ยังไม่จบ)
# [UPDATED] API ดึงกิจกรรม (เพิ่ม Logic กรองกิจกรรมบังคับที่ไม่เกี่ยวข้องออก)
@app.get("/activities", response_model=list[ActivityResponse])
def get_activities(mode: str = "all", emp_id: str | None = None, db: Session = Depends(get_db)):
    today = date.today()
    
    # 1. ดึงข้อมูลผู้เรียก API (ถ้าส่ง emp_id มา)
    requester = None
    req_dept = ""
    req_pos = ""
    
    if emp_id:
        requester = db.query(models.Employee).filter(models.Employee.EMP_ID == emp_id).first()
        if requester:
            req_dept = requester.department.DEP_NAME if requester.department else ""
            req_pos = requester.EMP_POSITION

    # 2. เตรียมข้อมูลเพื่อนับจำนวนคน (Logic เดิม)
    all_employees = db.query(models.Employee).filter(models.Employee.EMP_STATUS == 'Active').all()
    emp_data_list = []
    for emp in all_employees:
        emp_data_list.append({
            "dept_name": emp.department.DEP_NAME if emp.department else "",
            "position": emp.EMP_POSITION
        })
    
    # 3. Query Activities
    query = db.query(models.Activity).join(models.ActivitySession)
    if mode == "future":
        query = query.filter(models.ActivitySession.SESSION_DATE >= today)
        
    activities = query.distinct().all()
    
    # [NEW LOGIC] หาว่า User คนนี้ลงทะเบียนอะไรไปแล้วบ้าง
    registered_act_ids = set()
    if emp_id:
        # หาจากตาราง Registration
        user_regs = db.query(models.Registration).filter(models.Registration.EMP_ID == emp_id).all()
        for r in user_regs:
            # ต้อง Join ไปหา Activity ID ผ่าน Session
            sess = db.query(models.ActivitySession).filter(models.ActivitySession.SESSION_ID == r.SESSION_ID).first()
            if sess:
                registered_act_ids.add(sess.ACT_ID)
    
    results = []
    for act in activities:
        # =================================================================
        # [NEW LOGIC] Personalization Filter (คัดกรองกิจกรรม)
        # =================================================================
        if act.ACT_ISCOMPULSORY and requester:
            # ถ้าเป็นกิจกรรมบังคับ และเรารู้ตัวตนคนเรียก -> ต้องเช็คสิทธิ์การมองเห็น
            if act.ACT_TARGET_CRITERIA:
                try:
                    criteria = json.loads(act.ACT_TARGET_CRITERIA)
                    target_type = criteria.get('type', 'all')
                    
                    if target_type == 'specific':
                        # เช็คว่าคนเรียก ตรงเงื่อนไขไหม?
                        target_depts = criteria.get('departments', [])
                        target_positions = criteria.get('positions', [])
                        
                        is_match = False
                        # Rule 1: แผนกตรงไหม?
                        if req_dept in target_depts:
                            is_match = True
                        # Rule 2: ตำแหน่งตรงไหม?
                        if not is_match and req_pos in target_positions:
                            is_match = True
                            
                        # *** ถ้าไม่ตรงเงื่อนไขเลย -> ข้าม (ไม่ส่งกิจกรรมนี้กลับไป) ***
                        if not is_match:
                            continue 
                except:
                    pass # ถ้า JSON ผิดพลาด ให้แสดงไปก่อน (Fail-safe)
        # =================================================================

        # ... (Logic การนับจำนวน และส่วนอื่นๆ เหมือนเดิมเป๊ะ) ...
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
            sorted_sessions = sorted(act.sessions, key=lambda x: x.SESSION_DATE)
            if mode == "future":
                future_sessions = [s for s in sorted_sessions if s.SESSION_DATE >= today]
                if future_sessions:
                    target_session = future_sessions[0]
                else:
                    continue 
            else:
                target_session = sorted_sessions[0]

            start_time = target_session.START_TIME.strftime("%H:%M")
            end_time = target_session.END_TIME.strftime("%H:%M")
            location = f"{target_session.LOCATION}"
            act_date = target_session.SESSION_DATE
            
        org_name = "-"
        if act.organizer and act.organizer.employee:
            org_name = act.organizer.employee.EMP_NAME_EN
        
        # [NEW] เช็คสถานะ Registered
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
            # [NEW] เพิ่มสถานะการลงทะเบียน
            "isRegistered": is_reg
        })
        
    return results


# [NEW] API ดึงรายละเอียดกิจกรรมตาม ID
@app.get("/activities/{act_id}", response_model=ActivityDetailResponse)
def get_activity_detail(
    act_id: str, 
    emp_id: str | None = None, # [FIX] ต้องเพิ่มตรงนี้ครับ!
    db: Session = Depends(get_db)
):
    act = db.query(models.Activity).filter(models.Activity.ACT_ID == act_id).first()
    if not act:
        raise HTTPException(status_code=404, detail="Activity not found")
    
    # นับจำนวนผู้เข้าร่วม
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

    # [NEW] Check User Registration
    is_registered = False
    registered_session_id = None
    
    if emp_id:
        # หาว่า User ลงทะเบียน Session ไหนของกิจกรรมนี้บ้าง
        user_reg = db.query(models.Registration)\
            .join(models.ActivitySession)\
            .filter(
                models.Registration.EMP_ID == emp_id,
                models.ActivitySession.ACT_ID == act_id
            ).first()
            
        if user_reg:
            is_registered = True
            registered_session_id = user_reg.SESSION_ID

    # ข้อมูลผู้จัด
    org_name = "-"
    org_contact = "-"
    if act.organizer:
        org_contact = act.organizer.ORG_CONTACT_INFO
        if act.organizer.employee:
            org_name = act.organizer.employee.EMP_NAME_EN

    # ข้อมูลแผนก (Query แยกเพราะใน Model Activity อาจยังไม่ได้ผูก relationship department ไว้แบบสมบูรณ์)
    dep_name = "-"
    dep = db.query(models.Department).filter(models.Department.DEP_ID == act.DEP_ID).first()
    if dep:
        dep_name = dep.DEP_NAME

    # เตรียมข้อมูล Sessions
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
        "actImage": act.ACT_IMAGE, # [NEW] map ค่าจาก DB
        "agenda": act.ACT_AGENDA, # [NEW]
        "targetCriteria": act.ACT_TARGET_CRITERIA,
        "isFavorite": is_fav,
        "isRegistered": is_registered, # [NEW]
        "sessions": sessions_data
    }

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

        final_dep_id = resolve_department_id(db, data.DEP_ID, current_company_id)

        new_act_id = generate_id("A")
        while db.query(models.Activity).filter(models.Activity.ACT_ID == new_act_id).first():
            new_act_id = generate_id("A")

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
            ACT_MAX_PARTICIPANTS=data.ACT_MAX_PARTICIPANTS,
            ACT_EVENT_HOST=data.ACT_EVENT_HOST,
            ACT_GUEST_SPEAKER=data.ACT_GUEST_SPEAKER,
            ACT_FOOD_INFO=data.ACT_FOOD_INFO,
            ACT_TRAVEL_INFO=data.ACT_TRAVEL_INFO,
            ACT_MORE_DETAILS=data.ACT_MORE_DETAILS,
            ACT_TARGET_CRITERIA=data.ACT_TARGET_CRITERIA,
            ACT_IMAGE=data.ACT_IMAGE,
            ACT_AGENDA=data.ACT_AGENDA
        )
        db.add(new_activity)

        for s in req.SESSIONS:
            new_sess_id = generate_id("S", 6)
            while db.query(models.ActivitySession).filter(models.ActivitySession.SESSION_ID == new_sess_id).first():
                 new_sess_id = generate_id("S", 6)
            
            sess_date = datetime.strptime(s.SESSION_DATE.split('T')[0], "%Y-%m-%d").date()
            t_start = parse_time_safe(s.START_TIME) # ใช้ Function ใหม่ที่ปลอดภัย
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
        
        db.commit()
        return {"message": "Activity created successfully", "actId": new_act_id}

    except Exception as e:
        db.rollback()
        print(f"Create Error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to create: {str(e)}")


# [UPDATED] API แก้ไขกิจกรรม (Update แบบปลอดภัย + Reset Status)
@app.put("/activities/{act_id}")
def update_activity(act_id: str, req: ActivityFormRequest, db: Session = Depends(get_db)):
    # 1. ดึงข้อมูลกิจกรรม
    act = db.query(models.Activity).filter(models.Activity.ACT_ID == act_id).first()
    if not act:
        raise HTTPException(status_code=404, detail="Activity not found")

    # 2. อัปเดตข้อมูลหลัก (Activity Info)
    data = req.ACTIVITY
    current_company_id = act.COMPANY_ID 
    final_dep_id = resolve_department_id(db, data.DEP_ID, current_company_id)

    act.ACT_NAME = data.ACT_NAME
    act.ACT_TYPE = data.ACT_TYPE
    act.ACT_DESCRIPTIONS = data.ACT_DESCRIPTIONS
    act.ACT_POINT = data.ACT_POINT
    act.ACT_GUEST_SPEAKER = data.ACT_GUEST_SPEAKER
    act.ACT_EVENT_HOST = data.ACT_EVENT_HOST
    act.ACT_MAX_PARTICIPANTS = data.ACT_MAX_PARTICIPANTS
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

    if act.organizer:
        act.organizer.ORG_CONTACT_INFO = req.ORGANIZER.ORG_CONTACT_INFO
    
    # 3. [FIXED] จัดการ Session แบบฉลาด (Smart Update & Status Reset)
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
            # Update Existing
            session = existing_sessions[i]
            session.SESSION_DATE = sess_date
            session.START_TIME = t_start
            session.END_TIME = t_end
            session.LOCATION = s_data.LOCATION
            
            # [FIXED] ถ้าเลื่อนวันมาเป็นปัจจุบันหรืออนาคต ให้เปิดสถานะ Open อัตโนมัติ
            if sess_date >= date.today():
                session.SESSION_STATUS = "Open"
                
        else:
            # Create New
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
    
    # ลบ Session ส่วนเกิน (ถ้าไม่มีคนลงทะเบียน)
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
        return {"message": "Activity updated successfully"}
    except Exception as e:
        db.rollback()
        print(f"Update Error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to update: {str(e)}")

# [NEW] API ดึงรายชื่อแผนกทั้งหมด (สำหรับใส่ Dropdown)
@app.get("/departments")
def get_departments(db: Session = Depends(get_db)):
    deps = db.query(models.Department).all()
    return [{"id": d.DEP_ID, "name": d.DEP_NAME} for d in deps]

# [NEW] API ดึงรายชื่อตำแหน่งทั้งหมด (Distinct จากตารางพนักงาน)
@app.get("/positions")
def get_positions(db: Session = Depends(get_db)):
    # ดึงตำแหน่งที่ไม่ซ้ำกัน
    positions = db.query(models.Employee.EMP_POSITION).distinct().all()
    # positions จะเป็น list of tuples [('Dev',), ('HR',)] ต้องแปลงเป็น list of strings
    return [p[0] for p in positions if p[0]]

# --- Helper Function สำหรับจัดการแผนก (ใช้ใน Create/Update Activity) ---
def resolve_department_id(db: Session, dep_input: str, company_id: str):
    # 1. ลองหาจาก ID ก่อน
    dep = db.query(models.Department).filter(models.Department.DEP_ID == dep_input).first()
    if dep:
        return dep.DEP_ID
    
    # 2. ถ้าไม่เจอ ID ลองหาจาก ชื่อ (เผื่อส่งมาเป็นชื่อที่มีอยู่แล้ว)
    dep = db.query(models.Department).filter(
        models.Department.DEP_NAME == dep_input,
        models.Department.COMPANY_ID == company_id
    ).first()
    if dep:
        return dep.DEP_ID
    
    # 3. ถ้าไม่เจอเลย แสดงว่าเป็น "Other" (แผนกใหม่) -> สร้างใหม่เลย
    new_dep_id = generate_id("D")
    while db.query(models.Department).filter(models.Department.DEP_ID == new_dep_id).first():
            new_dep_id = generate_id("D")
    
    new_dep = models.Department(
        DEP_ID=new_dep_id,
        COMPANY_ID=company_id,
        DEP_NAME=dep_input # ใช้ชื่อที่ส่งมาตั้งเป็นชื่อแผนก
    )
    db.add(new_dep)
    db.commit() # บันทึกทันทีเพื่อให้ใช้ ID ได้
    db.refresh(new_dep)
    
    return new_dep.DEP_ID

@app.delete("/activities/{act_id}")
def delete_activity(act_id: str, db: Session = Depends(get_db)):
    # 1. หา Activity ก่อน
    act = db.query(models.Activity).filter(models.Activity.ACT_ID == act_id).first()
    if not act:
        raise HTTPException(status_code=404, detail="Activity not found")

    try:
        # 2. ลบข้อมูลที่เกี่ยวข้อง (Child Records) ตามลำดับ FK
        
        # 2.1 ลบ Favorites
        db.query(models.Favorite).filter(models.Favorite.ACT_ID == act_id).delete()
        
        # 2.2 ลบ Notifications
        db.query(models.Notification).filter(models.Notification.ACT_ID == act_id).delete()

        # 2.3 ลบ Registration & CheckIn (ต้องหา Session ก่อน)
        sessions = db.query(models.ActivitySession).filter(models.ActivitySession.ACT_ID == act_id).all()
        for s in sessions:
            # ลบ Registration ของ Session นี้
            db.query(models.Registration).filter(models.Registration.SESSION_ID == s.SESSION_ID).delete()
            # ลบ CheckIn ของ Session นี้
            db.query(models.CheckIn).filter(models.CheckIn.SESSION_ID == s.SESSION_ID).delete()

        # 2.4 ลบ ActivitySession ทั้งหมด
        db.query(models.ActivitySession).filter(models.ActivitySession.ACT_ID == act_id).delete()

        # 3. ลบตัว Activity หลัก
        db.delete(act)
        
        db.commit()
        return {"message": "Activity deleted successfully"}

    except Exception as e:
        db.rollback()
        print(f"Delete Error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to delete: {str(e)}")

@app.get("/activities/{act_id}/participants", response_model=list[ParticipantResponse])
def get_activity_participants(act_id: str, db: Session = Depends(get_db)):
    # 1. หา Session ทั้งหมดของกิจกรรมนี้
    sessions = db.query(models.ActivitySession).filter(models.ActivitySession.ACT_ID == act_id).all()
    session_ids = [s.SESSION_ID for s in sessions]

    if not session_ids:
        return []

    # 2. ดึงคนลงทะเบียน (Registration)
    regs = db.query(models.Registration).filter(models.Registration.SESSION_ID.in_(session_ids)).all()

    # 3. ดึงคนเช็คอิน (CheckIn) เอามาทำ Map เพื่อให้ค้นหาเร็ว O(1)
    checkins = db.query(models.CheckIn).filter(models.CheckIn.SESSION_ID.in_(session_ids)).all()
    checked_in_map = {c.EMP_ID: c.CHECKIN_TIME for c in checkins}

    results = []
    # ใช้ Set เพื่อป้องกันชื่อซ้ำ (กรณีลงหลายรอบ)
    processed_emp_ids = set()

    for r in regs:
        emp = r.employee
        if emp.EMP_ID in processed_emp_ids:
            continue
            
        processed_emp_ids.add(emp.EMP_ID)
        
        status = "Registered"
        check_in_time = "-"

        # ตรวจสอบว่าเช็คอินหรือยัง
        if emp.EMP_ID in checked_in_map:
            status = "Joined"
            # แปลงเวลาเป็น HH:MM
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
    # 1. Validate Employee
    employee = db.query(models.Employee).filter(models.Employee.EMP_ID == req.emp_id).first()
    if not employee:
        raise HTTPException(status_code=404, detail="ไม่พบข้อมูลพนักงาน")

    # 2. Validate Activity & Find Active Session
    # ดึงข้อมูล Activity มาก่อน เพื่อเช็คว่าเป็น Compulsory หรือไม่
    activity = db.query(models.Activity).filter(models.Activity.ACT_ID == req.act_id).first()
    if not activity:
        raise HTTPException(status_code=404, detail="ไม่พบข้อมูลกิจกรรม")

    now = datetime.now() # เวลา Server (The Source of Truth)
    
    # หา Session ของวันนี้
    sessions = db.query(models.ActivitySession).filter(
        models.ActivitySession.ACT_ID == req.act_id,
        models.ActivitySession.SESSION_DATE == now.date()
    ).all()

    if not sessions:
         raise HTTPException(status_code=400, detail="ไม่มีรอบกิจกรรมในวันนี้")

    target_session = None
    time_error_message = ""
    
    for sess in sessions:
        start_dt = datetime.combine(sess.SESSION_DATE, sess.START_TIME)
        end_dt = datetime.combine(sess.SESSION_DATE, sess.END_TIME)
        
        # --- [CORE LOGIC UPDATED] ---
        
        # 1. เวลาเปิดให้เช็คอิน (เหมือนกันทั้งสองแบบ) = ก่อนเริ่ม 1 ชั่วโมง
        window_open = start_dt - timedelta(hours=1)
        
        # 2. เวลาปิดรับเช็คอิน (แยกเงื่อนไข)
        if activity.ACT_ISCOMPULSORY:
            # แบบบังคับ: ให้สายได้แค่ 30 นาทีหลังจากเริ่ม
            window_close = start_dt + timedelta(minutes=30)
            condition_text = "ภายใน 30 นาทีแรก"
        else:
            # แบบทั่วไป: เช็คอินได้จนจบกิจกรรม
            window_close = end_dt
            condition_text = "ก่อนกิจกรรมจบ"
            
        # ตรวจสอบช่วงเวลา
        if window_open <= now <= window_close:
            target_session = sess
            break # เจอ Session ที่ลงได้แล้ว จบ loop
        else:
            # เก็บข้อความ Error ไว้ เผื่อไม่เจอ Session ไหนเลยจะได้แจ้งถูก
            time_error_message = f"ไม่อยู่ในช่วงเวลาเช็คอิน ({condition_text})"

    if not target_session:
         # ถ้าวนลูปครบแล้วยังหา Session ที่ลงได้ไม่เจอ
         raise HTTPException(status_code=400, detail=time_error_message or "ไม่อยู่ในช่วงเวลากิจกรรม")

    # 3. Check Registration (เหมือนเดิม)
    reg = db.query(models.Registration).filter(
        models.Registration.EMP_ID == req.emp_id,
        models.Registration.SESSION_ID == target_session.SESSION_ID
    ).first()
    
    if not reg:
        raise HTTPException(status_code=400, detail="พนักงานยังไม่ได้ลงทะเบียนกิจกรรมนี้")

    # 4. Check Duplicate (เหมือนเดิม)
    existing_checkin = db.query(models.CheckIn).filter(
        models.CheckIn.EMP_ID == req.emp_id,
        models.CheckIn.SESSION_ID == target_session.SESSION_ID
    ).first()
    
    if existing_checkin:
        raise HTTPException(status_code=400, detail="พนักงานเช็คอินเรียบร้อยแล้ว")

    try:
        # 5. Process Check-in (เหมือนเดิม)
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
        
        # 6. Update Points & Transaction (เหมือนเดิม)
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
        
        db.commit()
        
        await manager.broadcast(f"CHECKIN_SUCCESS|{req.emp_id}|{activity.ACT_NAME}|{req.scanned_by}")
        
        await manager.broadcast("REFRESH_PARTICIPANTS")
        
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

# [NEW] API ดึงกิจกรรมที่ฉันลงทะเบียนไว้ (เฉพาะที่ยังไม่จบ)
# ค้นหา @app.get("/my-activities/{emp_id}"...) และแทนที่ฟังก์ชันด้วย Code นี้ครับ

@app.get("/my-activities/{emp_id}", response_model=list[MyActivityResponse])
def get_my_upcoming_activities(emp_id: str, db: Session = Depends(get_db)):
    today = date.today()
    
    # 1. ดึงข้อมูลพนักงาน
    employee = db.query(models.Employee).filter(models.Employee.EMP_ID == emp_id).first()
    if not employee:
        raise HTTPException(status_code=404, detail="Employee not found")
        
    emp_dept_name = employee.department.DEP_NAME if employee.department else ""
    emp_position = employee.EMP_POSITION
    
    # --- ส่วนที่ 1: กิจกรรมที่ "ลงทะเบียนแล้ว" ---
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
        models.ActivitySession.SESSION_DATE >= today,
        models.CheckIn.CHECKIN_ID == None 
    ).all()

    registered_act_ids = {act.ACT_ID for _, _, act in registered_acts}
    output = []

    for reg, sess, act in registered_acts:
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
            # [FIXED] เพิ่ม 2 บรรทัดนี้ เพื่อให้ตรงกับ Model ใหม่
            "isCompulsory": act.ACT_ISCOMPULSORY == 1,
            "point": act.ACT_POINT
        })

    # --- ส่วนที่ 2: กิจกรรม "บังคับ" (Auto-Add) ---
    compulsory_acts = db.query(models.Activity).join(models.ActivitySession).filter(
        models.Activity.ACT_ISCOMPULSORY == True,
        models.ActivitySession.SESSION_DATE >= today
    ).distinct().all()

    for act in compulsory_acts:
        if act.ACT_ID in registered_act_ids:
            continue 
            
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
                    if emp_dept_name in target_depts:
                        is_target = True
                    
                    target_positions = criteria.get('positions', [])
                    if not is_target and emp_position in target_positions:
                        is_target = True
            except Exception as e:
                print(f"Error parsing criteria: {e}")
                is_target = False

        if is_target:
            future_sessions = [s for s in act.sessions if s.SESSION_DATE >= today]
            if not future_sessions: continue
            
            target_session = sorted(future_sessions, key=lambda x: (x.SESSION_DATE, x.START_TIME))[0]
            
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
                # [FIXED] เพิ่ม 2 บรรทัดนี้
                "isCompulsory": True,
                "point": act.ACT_POINT
            })
        
    output.sort(key=lambda x: (x['activityDate'], x['startTime']))
    
    return output[:5]



@app.post("/favorites/toggle")
def toggle_favorite(req: ToggleFavoriteRequest, db: Session = Depends(get_db)):
    # เช็คว่ามีอยู่แล้วไหม
    existing_fav = db.query(models.Favorite).filter(
        models.Favorite.EMP_ID == req.emp_id,
        models.Favorite.ACT_ID == req.act_id
    ).first()

    if existing_fav:
        # ถ้ามี -> ลบออก (Unfavorite)
        db.delete(existing_fav)
        db.commit()
        return {"status": "removed", "message": "Removed from favorites"}
    else:
        # ถ้าไม่มี -> เพิ่มใหม่ (Favorite)
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
    # คืนค่าเป็น List ของ ACT_ID ที่ User นี้กด Fav ไว้
    favs = db.query(models.Favorite.ACT_ID).filter(models.Favorite.EMP_ID == emp_id).all()
    # favs จะเป็น list of tuples [('A001',), ('A002',)] ต้องแปลงเป็น list of strings
    return [f[0] for f in favs]

# [NEW] API ดึงประวัติการลงทะเบียนทั้งหมดของพนักงาน (Upcoming, Joined, Missed)
@app.get("/my-registrations/{emp_id}", response_model=list[MyActivityResponse])
def get_my_registrations(emp_id: str, db: Session = Depends(get_db)):
    today = date.today()
    
    # 1. ดึงข้อมูลการลงทะเบียนทั้งหมดของพนักงาน
    regs = db.query(models.Registration).filter(models.Registration.EMP_ID == emp_id).all()
    
    output = []
    for r in regs:
        # หา Session และ Activity ที่เกี่ยวข้อง
        sess = db.query(models.ActivitySession).filter(models.ActivitySession.SESSION_ID == r.SESSION_ID).first()
        if not sess: continue
        
        act = db.query(models.Activity).filter(models.Activity.ACT_ID == sess.ACT_ID).first()
        if not act: continue
        
        # 2. เช็คว่ามีการเช็คอินหรือยัง?
        checkin = db.query(models.CheckIn).filter(
            models.CheckIn.EMP_ID == emp_id, 
            models.CheckIn.SESSION_ID == sess.SESSION_ID
        ).first()
        
        # 3. คำนวณสถานะ (Logic หัวใจสำคัญ)
        status = "Upcoming"
        if checkin:
            status = "Joined"
        elif sess.SESSION_DATE < today:
            status = "Missed"
        # ถ้า date >= today และยังไม่ checkin ก็เป็น Upcoming
        
        output.append({
            "actId": act.ACT_ID,
            "actType": act.ACT_TYPE,
            "name": act.ACT_NAME,
            "location": sess.LOCATION,
            "activityDate": sess.SESSION_DATE,
            "startTime": sess.START_TIME.strftime("%H:%M"),
            "endTime": sess.END_TIME.strftime("%H:%M"),
            "status": status, # ส่งสถานะที่คำนวณแล้วกลับไป
            
            "sessionId": sess.SESSION_ID
        })
    
    # เรียงลำดับ: วันที่ล่าสุดขึ้นก่อน
    output.sort(key=lambda x: x['activityDate'], reverse=True)
        
    return output



# [UPDATED] API ยกเลิกการลงทะเบียน พร้อม Business Logic
@app.post("/activities/unregister")
def unregister_activity(req: UnregisterRequest, db: Session = Depends(get_db)):
    # 1. หา Record การลงทะเบียน
    reg = db.query(models.Registration).filter(
        models.Registration.EMP_ID == req.emp_id,
        models.Registration.SESSION_ID == req.session_id
    ).first()
    
    if not reg:
        raise HTTPException(status_code=404, detail="Registration not found")
        
    # 2. ดึงข้อมูล Session และ Activity เพื่อมาเช็คกฎ
    session = db.query(models.ActivitySession).filter(
        models.ActivitySession.SESSION_ID == req.session_id
    ).first()
    
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    activity = db.query(models.Activity).filter(
        models.Activity.ACT_ID == session.ACT_ID
    ).first()
    
    if not activity:
        raise HTTPException(status_code=404, detail="Activity not found")
    
    # --- Rule 1: Compulsory Check ---
    if activity.ACT_ISCOMPULSORY:
        raise HTTPException(
            status_code=400, 
            detail="กิจกรรมบังคับ ไม่สามารถยกเลิกได้ (กรุณาติดต่อ HR)"
        )

    # --- Rule 2: Time Limit Check (24 Hours) ---
    # รวมวันที่และเวลาเข้าด้วยกัน
    session_datetime = datetime.combine(session.SESSION_DATE, session.START_TIME)
    current_datetime = datetime.now()
    
    # หาความต่างของเวลา
    time_difference = session_datetime - current_datetime
    
    # ถ้าเหลือน้อยกว่า 24 ชม. ห้ามยกเลิก
    if time_difference < timedelta(hours=24):
        raise HTTPException(
            status_code=400, 
            detail="ไม่สามารถยกเลิกได้ (ต้องล่วงหน้าอย่างน้อย 24 ชม.)"
        )
    
    # ถ้าผ่านทุกกฎ -> ลบได้
    try:
        db.delete(reg)
        db.commit()
        return {"message": "Unregistered successfully"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))


# 1. ดึงรายการของรางวัล
@app.get("/rewards", response_model=list[PrizeResponse])
def get_rewards(db: Session = Depends(get_db)):
    prizes = db.query(models.Prize).filter(models.Prize.STATUS == 'Available').all()
    
    results = []
    for p in prizes:
        prize_type_str = str(p.PRIZE_TYPE) if p.PRIZE_TYPE else 'Physical'
        results.append({
            "id": p.PRIZE_ID,
            "name": p.PRIZE_NAME,
            "pointCost": p.PRIZE_POINTS,
            "description": p.PRIZE_DESCRIPTION or "-",
            "image": p.PRIZE_IMAGE,
            "stock": p.STOCK,
            "category": "General",
            "status": p.STATUS,
            "prizeType": prize_type_str,   # ส่งออกแล้ว
        })
    return results



# 2. ดึงประวัติการแลกของฉัน
@app.get("/my-redemptions/{emp_id}", response_model=list[MyRedemptionResponse])
def get_my_redemptions(emp_id: str, db: Session = Depends(get_db)):
    redemptions = db.query(models.Redeem).filter(models.Redeem.EMP_ID == emp_id).order_by(models.Redeem.REDEEM_DATE.desc()).all()
    
    results = []
    for r in redemptions:
        prize = db.query(models.Prize).filter(models.Prize.PRIZE_ID == r.PRIZE_ID).first()
        if prize:
            results.append({
                "redeemId": r.REDEEM_ID,
                "prizeName": prize.PRIZE_NAME,
                "pointCost": prize.PRIZE_POINTS,
                "redeemDate": r.REDEEM_DATE,
                "status": r.STATUS,
                "image": prize.PRIZE_IMAGE,
                
                # [NEW] ส่งค่าจาก DB ไป (ถ้าไม่มีให้ใช้ Default)
                "pickupInstruction": prize.PICKUP_INSTRUCTION or "Contact HR"
            })
    return results

@app.post("/rewards/redeem")
async def redeem_reward(req: RedeemRequest, db: Session = Depends(get_db)):
    # ... (Logic เช็คแต้ม/สต็อก เหมือนเดิม) ...
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
        # 4. ตัดยอด
        emp_points.TOTAL_POINTS -= prize.PRIZE_POINTS
        prize.STOCK -= 1
        
        # [SIMPLIFIED LOGIC] กำหนดสถานะตามประเภท
        voucher_code = None
        usage_expire = None
        status = "Pending" # Default รอรับของ
        
        if prize.PRIZE_TYPE == 'Privilege':
            # วันลา/สิทธิ์พิเศษ -> อนุมัติเลย (Completed) ใช้ได้ถึงสิ้นปี
            status = "Completed"
            this_year = datetime.now().year
            usage_expire = datetime(this_year, 12, 31, 23, 59, 59)
            
        elif prize.PRIZE_TYPE == 'Digital':
            # คูปอง -> รอ Admin ส่งโค้ดให้ (Pending)
            status = "Pending"
            # (อนาคตค่อยมาแก้ตรงนี้ถ้าจะ Auto-Gen)
            
        # Physical -> Pending (รอไปรับ)
        
        new_redeem_id = generate_id("RD", 8)
        new_redeem = models.Redeem(
            REDEEM_ID=new_redeem_id,
            EMP_ID=req.emp_id,
            PRIZE_ID=req.prize_id,
            REDEEM_DATE=datetime.now(),
            STATUS=status,
            APPROVED_BY=None,
            VOUCHER_CODE=voucher_code, # เป็น Null ไปก่อน
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
        
        db.commit()
        await manager.broadcast("REFRESH_REWARDS")
        
        return {
            "message": "Redemption successful", 
            "remaining_points": emp_points.TOTAL_POINTS,
            "redeem_id": new_redeem_id
        }
        
    except Exception as e:
        db.rollback()
        print(f"Redeem Error: {e}")
        raise HTTPException(status_code=500, detail=f"Transaction failed: {str(e)}")


@app.post("/activities/register")
async def register_activity(req: ActivityRegisterRequest, db: Session = Depends(get_db)):
    # 1. เช็คว่าเคยลงหรือยัง
    existing = db.query(models.Registration).filter(
        models.Registration.EMP_ID == req.emp_id,
        models.Registration.SESSION_ID == req.session_id
    ).first()
    
    if existing:
        raise HTTPException(status_code=400, detail="Already registered")
        
    # 2. เช็คที่ว่าง (Optional: ถ้าจะทำ Enterprise จริงต้องเช็ค Max Participants ด้วย)
    
    try:
        new_reg_id = generate_id("R", 8)
        new_reg = models.Registration(
            REG_ID=new_reg_id,
            EMP_ID=req.emp_id,
            SESSION_ID=req.session_id,
            REG_DATE=date.today()
        )
        db.add(new_reg)
        db.commit()
        
        # [FIXED] ตะโกนบอกทุกคนว่า "มีคนลงทะเบียนเพิ่มแล้วนะ!"
        await manager.broadcast("REFRESH_PARTICIPANTS")
        
        return {"message": "Registration successful", "reg_id": new_reg_id}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/rewards/cancel")
async def cancel_redemption(req: CancelRedeemRequest, db: Session = Depends(get_db)):
    # 1. ดึงข้อมูลการแลก
    redeem = db.query(models.Redeem).filter(
        models.Redeem.REDEEM_ID == req.redeem_id,
        models.Redeem.EMP_ID == req.emp_id
    ).first()
    
    if not redeem:
        raise HTTPException(status_code=404, detail="Redemption record not found")
        
    if redeem.STATUS != 'Pending':
        raise HTTPException(status_code=400, detail="Cannot cancel completed or already cancelled item")

    # 2. ดึงข้อมูลของรางวัลและกระเป๋าตังค์
    prize = db.query(models.Prize).filter(models.Prize.PRIZE_ID == redeem.PRIZE_ID).first()
    emp_points = db.query(models.Points).filter(models.Points.EMP_ID == req.emp_id).first()
    
    try:
        # 3. คืนของและคืนแต้ม (Refund Transaction)
        # 3.1 เปลี่ยนสถานะ
        redeem.STATUS = 'Cancelled'
        
        # 3.2 คืนสต็อก
        if prize:
            prize.STOCK += 1
            
        # 3.3 คืนแต้ม
        if emp_points and prize:
            emp_points.TOTAL_POINTS += prize.PRIZE_POINTS
            
            # 3.4 บันทึก Transaction Log (Refund)
            new_txn_id = generate_id("TXN", 10)
            new_txn = models.PointTransaction(
                TXN_ID=new_txn_id,
                EMP_ID=req.emp_id,
                TXN_TYPE="Refund",
                REF_TYPE="REDEEM",
                REF_ID=redeem.REDEEM_ID,
                POINTS=prize.PRIZE_POINTS, # แต้มบวกกลับ
                TXN_DATE=datetime.now()
            )
            db.add(new_txn)
            
        db.commit()
        
        # [NEW] ตะโกนบอกทุกคนว่า "ของรางวัลมีการเปลี่ยนแปลงนะ" (Stock เพิ่มกลับมา)
        await manager.broadcast("REFRESH_REWARDS")
        
        return {
            "message": "Cancelled successfully", 
            "remaining_points": emp_points.TOTAL_POINTS if emp_points else 0
        }
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Cancel failed: {str(e)}")

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            # รอรับข้อความ (Keep Alive)
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)
        
# หมายเหตุ: อย่าลืมรัน uvicorn ใหม่ทุกครั้งหลังแก้ไฟล์
# uvicorn main:app --reload --host 0.0.0.0 --port 8000
