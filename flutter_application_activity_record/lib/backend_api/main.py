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
import io
from fastapi import File, UploadFile, Form

# สร้างตารางใน DB อัตโนมัติ (ถ้ายังไม่มี)
models.Base.metadata.create_all(bind=engine)

app = FastAPI()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# --- Schemas (ตัวกำหนดรูปแบบข้อมูลที่รับส่ง) ---
class ForgotPasswordRequest(BaseModel):
    email: str

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

@app.post("/login")
def login(req: LoginRequest, db: Session = Depends(get_db)):
    # 1. ค้นหา Employee จาก Email
    user = db.query(models.Employee).filter(models.Employee.EMP_EMAIL == req.email).first()
    
    # 2. ตรวจสอบว่ามี User ไหม และ Password ตรงกันไหม
    if not user or not verify_password(req.password, user.EMP_PASSWORD):
        raise HTTPException(status_code=400, detail="อีเมลหรือรหัสผ่านไม่ถูกต้อง")
    
    # 3. ส่งข้อมูลกลับ (Role สำคัญมาก เพื่อให้ Flutter ตัดสินใจว่าจะไปหน้าไหน)
    return {
        "message": "Login successful",
        "role": user.EMP_ROLE,
        "emp_id": user.EMP_ID,
        "company_id": user.COMPANY_ID, # ส่ง Company ID กลับไปด้วยเผื่อใช้
        "name": user.EMP_NAME_EN
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
    # 1. ค้นหาพนักงาน
    user = db.query(models.Employee).filter(models.Employee.EMP_ID == emp_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="ไม่พบข้อมูลพนักงาน")
    
    # 2. หาชื่อแผนก (ถ้ามี relationship แล้วใช้ user.department.DEP_NAME ได้เลย แต่เพื่อความชัวร์ผม query ให้ดู)
    dep_name = "-"
    if user.department:
        dep_name = user.department.DEP_NAME

    # 3. หาชื่อบริษัท
    comp_name = "-"
    if user.company:
        comp_name = user.company.COMPANY_NAME

    # 4. ส่งข้อมูลกลับเป็น JSON
    return {
        "EMP_ID": user.EMP_ID,
        "EMP_TITLE_EN": user.EMP_TITLE_EN,  # คำนำหน้าชื่อ
        "EMP_NAME_EN": user.EMP_NAME_EN,    # ชื่ออังกฤษ
        "EMP_POSITION": user.EMP_POSITION,  # ตำแหน่ง
        "DEP_NAME": dep_name,               # ชื่อแผนก
        "COMPANY_NAME": comp_name,          # ชื่อบริษัท
        "EMP_EMAIL": user.EMP_EMAIL,        # อีเมล
        "EMP_PHONE": user.EMP_PHONE,        # เบอร์โทร
        "EMP_STARTDATE": user.EMP_STARTDATE # วันเริ่มงาน (เอาไปคำนวณอายุงาน)
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


# [NEW] API ดึงข้อมูลกิจกรรมทั้งหมด
@app.get("/activities", response_model=list[ActivityResponse])
def get_activities(db: Session = Depends(get_db)):
    activities = db.query(models.Activity).all()
    
    results = []
    for act in activities:
        # 1. คำนวณจำนวนผู้เข้าร่วม
        current_count = db.query(models.Registration)\
            .join(models.ActivitySession, models.Registration.SESSION_ID == models.ActivitySession.SESSION_ID)\
            .filter(models.ActivitySession.ACT_ID == act.ACT_ID)\
            .count()
            
        # 2. หาสถานที่
        location = "-"
        if act.sessions and len(act.sessions) > 0:
            first_session = act.sessions[0]
            start_time_str = first_session.START_TIME.strftime("%H:%M")
            location = f"{first_session.LOCATION} at : {start_time_str}"

        # 3. [NEW] หาชื่อผู้จัด (Organizer Name)
        org_name = "-"
        # เช็คว่ามีความสัมพันธ์เชื่อมไปถึง Employee ได้ไหม
        if act.organizer and act.organizer.employee:
            org_name = act.organizer.employee.EMP_NAME_EN
        
        results.append({
            "actId": act.ACT_ID,
            "orgId": act.ORG_ID,
            "organizerName": org_name, # [NEW] ส่งชื่อกลับไป
            "actType": act.ACT_TYPE,
            "isCompulsory": 1 if act.ACT_ISCOMPULSORY else 0,
            "point": act.ACT_POINT,
            "name": act.ACT_NAME,
            "maxParticipants": act.ACT_MAX_PARTICIPANTS,
            "status": act.ACT_STATUS,
            "currentParticipants": current_count,
            "location": location
        })
        
    return results


# [NEW] API ดึงรายละเอียดกิจกรรมตาม ID
@app.get("/activities/{act_id}", response_model=ActivityDetailResponse)
def get_activity_detail(act_id: str, db: Session = Depends(get_db)):
    act = db.query(models.Activity).filter(models.Activity.ACT_ID == act_id).first()
    if not act:
        raise HTTPException(status_code=404, detail="Activity not found")
    
    # นับจำนวนผู้เข้าร่วม
    current_count = db.query(models.Registration)\
        .join(models.ActivitySession, models.Registration.SESSION_ID == models.ActivitySession.SESSION_ID)\
        .filter(models.ActivitySession.ACT_ID == act.ACT_ID)\
        .count()
        
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
            ACT_TARGET_CRITERIA=data.ACT_TARGET_CRITERIA
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
# [UPDATED] API แก้ไขกิจกรรม (Update แบบปลอดภัย ไม่ลบ Session มั่ว)
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
    
    # 3. [FIXED] จัดการ Session แบบฉลาด (Smart Update)
    # แทนที่จะลบทิ้งหมด เราจะเช็คก่อน
    
    # ดึง Session เก่ามาเรียงตามเวลา
    existing_sessions = db.query(models.ActivitySession).filter(
        models.ActivitySession.ACT_ID == act_id
    ).order_by(models.ActivitySession.SESSION_DATE).all()

    # วนลูปเทียบ Session ใหม่ กับ อันเก่า
    for i, s_data in enumerate(req.SESSIONS):
        # แปลงข้อมูลเวลาเตรียมไว้
        try:
            sess_date = datetime.strptime(s_data.SESSION_DATE.split('T')[0], "%Y-%m-%d").date()
            t_start = parse_time_safe(s_data.START_TIME)
            t_end = parse_time_safe(s_data.END_TIME)
        except ValueError:
             continue # ข้ามถ้ารูปแบบเวลาผิด

        if i < len(existing_sessions):
            # กรณีมี Session เดิมอยู่แล้ว -> "อัปเดตทับ" (Update in-place)
            # วิธีนี้ ID เดิมยังอยู่ ข้อมูลการลงทะเบียนไม่หาย ไม่เกิด Error
            session = existing_sessions[i]
            session.SESSION_DATE = sess_date
            session.START_TIME = t_start
            session.END_TIME = t_end
            session.LOCATION = s_data.LOCATION
        else:
            # กรณี Session ใหม่เยอะกว่าอันเก่า -> "สร้างเพิ่ม" (Create new)
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
    
    # กรณี Session ใหม่น้อยกว่าอันเก่า (เช่น ลดวันจัดกิจกรรม) -> "ลบส่วนเกิน"
    # แต่ต้องเช็คก่อนว่ามีคนลงทะเบียนไหม ถ้ามี ลบไม่ได้ (ปล่อยค้างไว้ หรือแจ้งเตือน)
    if len(req.SESSIONS) < len(existing_sessions):
        for i in range(len(req.SESSIONS), len(existing_sessions)):
            sess_to_delete = existing_sessions[i]
            # เช็คว่ามีคนลงทะเบียนไหม
            reg_count = db.query(models.Registration).filter(
                models.Registration.SESSION_ID == sess_to_delete.SESSION_ID
            ).count()
            
            if reg_count == 0:
                # ไม่มีคนลงทะเบียน -> ลบได้
                db.delete(sess_to_delete)
            else:
                # มีคนลงทะเบียน -> ข้ามการลบ (เพื่อความปลอดภัย)
                print(f"Skipping delete session {sess_to_delete.SESSION_ID} because it has registrations.")

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

# หมายเหตุ: อย่าลืมรัน uvicorn ใหม่ทุกครั้งหลังแก้ไฟล์
# uvicorn main:app --reload --host 0.0.0.0 --port 8000
