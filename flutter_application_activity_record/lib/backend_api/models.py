from sqlalchemy import Column, String, Date, ForeignKey, Integer, DECIMAL, Text, Boolean, Time, DateTime
from sqlalchemy.orm import relationship
from database import Base

# --- 1. ตารางบริษัท ---
class Company(Base):
    __tablename__ = "COMPANY"
    COMPANY_ID = Column(String(10), primary_key=True, index=True)
    COMPANY_NAME = Column(String(100), nullable=False)
    TAX_ID = Column(String(13))
    ADDRESS = Column(String(255))
    BUSINESS_TYPE = Column(String(50))
    # หมายเหตุ: ใน SQL ยังไม่มี DOMAIN_NAME, LOGO_URL ถ้าต้องการใช้ต้องไปเพิ่ม Column ใน DB ด้วย

    # Relationships
    employees = relationship("Employee", back_populates="company")
    departments = relationship("Department", back_populates="company")
    activities = relationship("Activity", back_populates="company")
    prizes = relationship("Prize", back_populates="company")

# --- 2. ตารางแผนก ---
class Department(Base):
    __tablename__ = "DEPARTMENT"
    DEP_ID = Column(String(5), primary_key=True, index=True)
    COMPANY_ID = Column(String(10), ForeignKey("COMPANY.COMPANY_ID"), nullable=False)
    DEP_NAME = Column(String(50), nullable=False)

    # Relationships
    company = relationship("Company", back_populates="departments")
    employees = relationship("Employee", back_populates="department")

# --- 3. ตารางพนักงาน ---
class Employee(Base):
    __tablename__ = "EMPLOYEE"
    EMP_ID = Column(String(5), primary_key=True, index=True)
    COMPANY_ID = Column(String(10), ForeignKey("COMPANY.COMPANY_ID"), nullable=False)
    
    EMP_TITLE_EN = Column(String(20)) # ใน SQL มีแต่ EN
    EMP_NAME_EN = Column(String(50), nullable=False) # ใน SQL มีแต่ EN
    # หมายเหตุ: ถ้าต้องการเก็บชื่อไทย (TH) ต้องไปเพิ่ม Column ใน DB ก่อน

    EMP_POSITION = Column(String(50), nullable=False)
    DEP_ID = Column(String(5), ForeignKey("DEPARTMENT.DEP_ID"), nullable=False)
    EMP_PHONE = Column(String(10), nullable=False)
    EMP_EMAIL = Column(String(50), unique=True, nullable=False)
    EMP_PASSWORD = Column(String(100), nullable=False)
    EMP_STARTDATE = Column(Date, nullable=False)
    EMP_STATUS = Column(String(10), default="Active")
    EMP_ROLE = Column(String(20), nullable=False)
    OTP_CODE = Column(String(6), nullable=True)

    # Relationships
    company = relationship("Company", back_populates="employees")
    department = relationship("Department", back_populates="employees")
    organizer_profile = relationship("Organizer", back_populates="employee", uselist=False)
    points = relationship("Points", back_populates="employee", uselist=False)

# --- 4. ตารางผู้จัดกิจกรรม ---
class Organizer(Base):
    __tablename__ = "ORGANIZER"
    ORG_ID = Column(String(5), primary_key=True, index=True)
    EMP_ID = Column(String(5), ForeignKey("EMPLOYEE.EMP_ID"), nullable=False)
    ORG_CONTACT_INFO = Column(String(100), nullable=False)
    ORG_UNIT = Column(String(50), nullable=False)
    ORG_NOTE = Column(String(255))

    # Relationships
    employee = relationship("Employee", back_populates="organizer_profile")
    activities = relationship("Activity", back_populates="organizer")

# --- 5. ตารางกิจกรรม ---
class Activity(Base):
    __tablename__ = "ACTIVITY"
    ACT_ID = Column(String(5), primary_key=True, index=True)
    COMPANY_ID = Column(String(10), ForeignKey("COMPANY.COMPANY_ID"), nullable=False)
    ACT_NAME = Column(String(100), nullable=False)
    ACT_TYPE = Column(String(30), nullable=False)
    ACT_DESCRIPTIONS = Column(Text)
    ORG_ID = Column(String(5), ForeignKey("ORGANIZER.ORG_ID"), nullable=False)
    DEP_ID = Column(String(5), ForeignKey("DEPARTMENT.DEP_ID"), nullable=False)
    ACT_ISCOMPULSORY = Column(Boolean, default=False)
    ACT_POINT = Column(Integer, default=0)
    ACT_COST = Column(DECIMAL(10,2), default=0.00)
    ACT_PARTICIPATION_CONDITION = Column(String(100))
    ACT_STATUS = Column(String(20), default="Open")
    ACT_MAX_PARTICIPANTS = Column(Integer, nullable=False)
    ACT_EVENT_HOST = Column(String(100))
    ACT_GUEST_SPEAKER = Column(String(100))
    ACT_FOOD_INFO = Column(String(100))
    ACT_TRAVEL_INFO = Column(String(100))
    ACT_MORE_DETAILS = Column(Text)
    ACT_TARGET_CRITERIA = Column(Text, nullable=True)
    # [CHANGE] เปลี่ยนจาก ACT_IMAGE เป็น ACT_ATTACHMENTS เพื่อเก็บ JSON List
    # ตัวอย่างข้อมูล: '[{"url": "/static/img1.jpg", "type": "IMAGE", "name": "cover.jpg"}]'
    ACT_ATTACHMENTS = Column(Text, default="[]")
    
    # ACT_IMAGE = Column(String(255)) # <-- ของเดิม (เลิกใช้ หรือเก็บไว้เป็น Backward Compat)
    ACT_AGENDA = Column(Text)

    # Relationships
    company = relationship("Company", back_populates="activities")
    organizer = relationship("Organizer", back_populates="activities")
    sessions = relationship("ActivitySession", back_populates="activity")

# --- 6. ตารางรอบกิจกรรม ---
class ActivitySession(Base):
    __tablename__ = "ACTIVITY_SESSION"
    SESSION_ID = Column(String(6), primary_key=True, index=True)
    ACT_ID = Column(String(5), ForeignKey("ACTIVITY.ACT_ID"), nullable=False)
    SESSION_DATE = Column(Date, nullable=False)
    START_TIME = Column(Time, nullable=False)
    END_TIME = Column(Time, nullable=False)
    LOCATION = Column(String(100), nullable=False)
    SESSION_STATUS = Column(String(20), default="Open")

    activity = relationship("Activity", back_populates="sessions")

# --- 7. ตารางลงทะเบียน ---
class Registration(Base):
    __tablename__ = "REGISTRATION"
    REG_ID = Column(String(20), primary_key=True, index=True)
    EMP_ID = Column(String(5), ForeignKey("EMPLOYEE.EMP_ID"), nullable=False)
    SESSION_ID = Column(String(6), ForeignKey("ACTIVITY_SESSION.SESSION_ID"), nullable=False)
    REG_DATE = Column(Date, nullable=False)
    employee = relationship("Employee")
# --- 8. ตารางเช็คอิน ---
class CheckIn(Base):
    __tablename__ = "CHECKIN"
    CHECKIN_ID = Column(String(20), primary_key=True, index=True)
    EMP_ID = Column(String(5), ForeignKey("EMPLOYEE.EMP_ID"), nullable=False)
    SESSION_ID = Column(String(6), ForeignKey("ACTIVITY_SESSION.SESSION_ID"), nullable=False)
    CHECKIN_DATE = Column(Date, nullable=False)
    CHECKIN_TIME = Column(Time, nullable=False)
    POINTS_EARNED = Column(Integer, default=0)

# --- 9. ตารางคะแนนสะสม ---
class Points(Base):
    __tablename__ = "POINTS"
    EMP_ID = Column(String(5), ForeignKey("EMPLOYEE.EMP_ID"), primary_key=True)
    TOTAL_POINTS = Column(Integer, default=0, nullable=False)
    EXPIRY_DATE = Column(Date)

    employee = relationship("Employee", back_populates="points")

# --- 10. ตารางประวัติคะแนน (NEW) ---
class PointTransaction(Base):
    __tablename__ = "POINT_TRANSACTION"
    TXN_ID = Column(String(20), primary_key=True)
    EMP_ID = Column(String(5), ForeignKey("EMPLOYEE.EMP_ID"), nullable=False)
    TXN_TYPE = Column(String(10), nullable=False) # Earn / Redeem
    REF_TYPE = Column(String(10), nullable=False) # CHECKIN / REDEEM
    REF_ID = Column(String(20), nullable=False)
    POINTS = Column(Integer, nullable=False)
    TXN_DATE = Column(DateTime, nullable=False)
    

# --- 11. ตารางของรางวัล ---
class Prize(Base):
    __tablename__ = "PRIZE"
    PRIZE_ID = Column(String(5), primary_key=True, index=True)
    COMPANY_ID = Column(String(10), ForeignKey("COMPANY.COMPANY_ID"), nullable=False)
    PRIZE_NAME = Column(String(50), nullable=False)
    PRIZE_POINTS = Column(Integer, nullable=False)
    PRIZE_DESCRIPTION = Column(Text)
    PRIZE_IMAGES = Column(Text, default="[]")
    STOCK = Column(Integer, default=0)
    STATUS = Column(String(20), default="Available")
    EXPIRED_DATE = Column(Date)
    MANAGED_BY = Column(String(5), ForeignKey("EMPLOYEE.EMP_ID"), nullable=False)
    PICKUP_INSTRUCTION = Column(String(255), default='Contact HR')
    company = relationship("Company", back_populates="prizes")
    PRIZE_TYPE = Column(String(20), default='Physical') # Physical, Digital, Privilege
    EXTERNAL_LINK = Column(String(255), nullable=True)
# --- 12. ตารางแลกของรางวัล ---
class Redeem(Base):
    __tablename__ = "REDEEM"
    REDEEM_ID = Column(String(20), primary_key=True, index=True)
    EMP_ID = Column(String(5), ForeignKey("EMPLOYEE.EMP_ID"), nullable=False)
    PRIZE_ID = Column(String(5), ForeignKey("PRIZE.PRIZE_ID"), nullable=False)
    REDEEM_DATE = Column(DateTime)
    STATUS = Column(String(20), default="Pending")
    APPROVED_BY = Column(String(5), ForeignKey("EMPLOYEE.EMP_ID"))
    RECEIVED_DATE = Column(Date)
    VOUCHER_CODE = Column(String(50), nullable=True)
    USAGE_EXPIRED_DATE = Column(DateTime, nullable=True)
# --- 13. ตารางรายการโปรด (NEW) ---
class Favorite(Base):
    __tablename__ = "FAVORITE"
    FAV_ID = Column(String(5), primary_key=True)
    EMP_ID = Column(String(5), ForeignKey("EMPLOYEE.EMP_ID"), nullable=False)
    ACT_ID = Column(String(5), ForeignKey("ACTIVITY.ACT_ID"), nullable=False)
    FAV_DATE = Column(Date, nullable=False)

# --- 14. ตารางแจ้งเตือน (NEW) ---
class Notification(Base):
    __tablename__ = "NOTIFICATION"
    # เปลี่ยน Primary Key ให้ยาวขึ้นรองรับ NTxxxxxxxxxx
    NOTIF_ID = Column(String(20), primary_key=True) 
    EMP_ID = Column(String(5), ForeignKey("EMPLOYEE.EMP_ID"), nullable=False)
    
    # Display Data
    TITLE = Column(String(100), nullable=False)      # หัวข้อแจ้งเตือน
    MESSAGE = Column(Text, nullable=False)           # เนื้อหาละเอียด
    NOTIF_TYPE = Column(String(20), nullable=False)  # Activity, Reward, Alert, System
    
    # Navigation Data
    REF_ID = Column(String(20))                      # ID อ้างอิง (เช่น ACT_ID, REDEEM_ID)
    ROUTE_PATH = Column(String(50))                  # หน้าปลายทาง (เช่น /activity_detail)
    
    # Status
    IS_READ = Column(Boolean, default=False)         # อ่านหรือยัง
    CREATED_AT = Column(DateTime, nullable=False)    # เวลาที่สร้าง
    TARGET_ROLE = Column(String(20), nullable=False, default="Employee")
# --- 15. ตารางนโยบายคะแนน (NEW) ---
class PointPolicy(Base):
    __tablename__ = "POINT_POLICY"
    POLICY_ID = Column(String(8), primary_key=True)
    COMPANY_ID = Column(String(10), ForeignKey("COMPANY.COMPANY_ID"), nullable=False)
    POLICY_NAME = Column(String(50), nullable=False)
    START_PERIOD = Column(Date, nullable=False)
    END_PERIOD = Column(Date, nullable=False)
    DESCRIPTION = Column(String(255))