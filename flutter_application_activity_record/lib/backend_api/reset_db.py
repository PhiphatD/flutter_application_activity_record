from database import engine
from models import Base
import models # ต้อง import models เพื่อให้ Base รู้จักตารางทั้งหมด

def reset_database():
    print("กำลังลบตารางเก่าทั้งหมด...")
    # ลบทุกตารางที่ defined ใน models.py
    Base.metadata.drop_all(bind=engine)
    print("ลบตารางเสร็จสิ้น")

    print("กำลังสร้างตารางใหม่ตาม code ปัจจุบัน...")
    # สร้างตารางใหม่โดยมีคอลัมน์ครบถ้วน (รวม EMP_TITLE_TH)
    Base.metadata.create_all(bind=engine)
    print("สร้างตารางเสร็จสมบูรณ์! Database พร้อมใช้งานแล้ว")

if __name__ == "__main__":
    reset_database()