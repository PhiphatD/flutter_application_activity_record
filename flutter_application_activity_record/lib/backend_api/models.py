from sqlalchemy import Column, String, Date, ForeignKey, Integer, DECIMAL, Text, Boolean, Time, DateTime
from sqlalchemy.orm import relationship
from database import Base

# --- 1. ตารางบริษัท (New) ---
class Company(Base):
    __tablename__ = "COMPANY"
    COMPANY_ID = Column(String(10), primary_key=True, index=True)
    COMPANY_NAME = Column(String(100), nullable=False)
    TAX_ID = Column(String(13))
    ADDRESS = Column(String(255))
    BUSINESS_TYPE = Column(String(50))


    # Relationships
    employees = relationship("Employee", back_populates="company")
    departments = relationship("Department", back_populates="company")

# --- 2. ตารางแผนก (Updated) ---
class Department(Base):
    __tablename__ = "DEPARTMENT"
    DEP_ID = Column(String(5), primary_key=True, index=True)
    # เพิ่ม Company ID
    COMPANY_ID = Column(String(10), ForeignKey("COMPANY.COMPANY_ID"), nullable=False)
    DEP_NAME = Column(String(50), nullable=False)

    # Relationships
    company = relationship("Company", back_populates="departments")
    employees = relationship("Employee", back_populates="department")

# --- 3. ตารางพนักงาน (Updated) ---
class Employee(Base):
    __tablename__ = "EMPLOYEE"
    EMP_ID = Column(String(5), primary_key=True, index=True)
    # เพิ่ม Company ID และ Title
    COMPANY_ID = Column(String(10), ForeignKey("COMPANY.COMPANY_ID"), nullable=False)
    EMP_TITLE_EN = Column(String(20)) 
    EMP_NAME_EN = Column(String(50), nullable=False)
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