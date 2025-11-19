from fastapi import FastAPI, HTTPException, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel
from passlib.context import CryptContext
from datetime import date
import models
from database import engine, get_db
import random
import string
import smtplib 
from email.mime.text import MIMEText 
from email.mime.multipart import MIMEMultipart 


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
            EMP_STARTDATE=date.today(),
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

# หมายเหตุ: อย่าลืมรัน uvicorn ใหม่ทุกครั้งหลังแก้ไฟล์
# uvicorn main:app --reload --host 0.0.0.0 --port 8000
