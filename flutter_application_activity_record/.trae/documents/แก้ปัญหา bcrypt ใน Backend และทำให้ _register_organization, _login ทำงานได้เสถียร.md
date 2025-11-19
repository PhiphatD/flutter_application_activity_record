## ปัญหาที่พบ

* เกิดข้อความ “module 'bcrypt' has no attribute '__about__'” ระหว่างเริ่มใช้งาน bcrypt ผ่าน passlib

* เรียก `POST /register_organization` แล้ว 500 Internal Server Error เนื่องจาก `ValueError: password cannot be longer than 72 bytes`

## สาเหตุที่เป็นไปได้

* โมดูล `bcrypt` ที่ติดตั้งใน venv ไม่ใช่แพ็กเกจ PyPI ที่ถูกต้อง หรือเวอร์ชันไม่รองรับการ introspect ของ passlib

* ข้อจำกัดของ bcrypt: รหัสผ่านถูกจำกัดที่ 72 ไบต์ ถ้ายาวกว่านั้นบาง backend จะ `raise ValueError` (แทนที่จะ truncate เงียบๆ)

## แนวทางแก้แบบครบถ้วน

### 1) ทำให้การแฮช/ตรวจรหัสผ่านปลอดภัยต่อข้อจำกัด 72 ไบต์

* เพิ่ม helper function เพื่อ truncate เป็น 72 ไบต์แบบปลอดภัย

* ใช้ helper ในทั้ง `get_password_hash()` และ `verify_password()`

โค้ดที่จะปรับใน `lib/backend_api/main.py`:

```
# เพิ่ม helper
def _bcrypt_safe(password: str) -> str:
    pw_bytes = password.encode('utf-8') if isinstance(password, str) else password
    pw_bytes = pw_bytes[:72]
    return pw_bytes.decode('utf-8', errors='ignore')

# ปรับการใช้งาน
def get_password_hash(password):
    return pwd_context.hash(_bcrypt_safe(password))

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(_bcrypt_safe(plain_password), hashed_password)
```

### 2) ทำให้แพ็กเกจ bcrypt/passlib ใน venv ถูกต้อง

* อัปเกรด/ติดตั้งแพ็กเกจ PyPI ที่ถูกต้องใน venv เพื่อลด error introspect

* คำสั่ง (Windows):

  * `.\.venv\Scripts\python.exe -m pip install -U bcrypt passlib`

  * หากยังมีปัญหา ให้ปักเวอร์ชัน: `.\.venv\Scripts\python.exe -m pip install bcrypt==4.1.2 passlib==1.7.4`

### 3) รีสตาร์ทเซิร์ฟเวอร์และทดสอบ

* รีรัน: `py -m uvicorn lib.backend_api.main:app --reload --host 0.0.0.0 --port 8000`

* ทดสอบ

  * `POST /register_organization` ด้วยข้อมูลปกติ → ควรได้ 200 และ `{message, emp_id}`

  * `POST /login` ด้วย email/password ที่สมัครไว้ → ควรได้ `{message, role, emp_id, name}`

### 4) เสริมความทนทานฝั่ง Flutter

* ฝั่ง Flutter มีการแสดง SnackBar เมื่อ status != 200 อยู่แล้ว ไม่ต้องแก้เพิ่ม แต่ถ้า body ไม่ใช่ JSON จะถูกจับใน catch และแสดงข้อความ “ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้” ซึ่งเพียงพอสำหรับตอนนี้

## สิ่งที่จะดำเนินการเมื่ออนุมัติ

1. แก้ไฟล์ `lib/backend_api/main.py` ให้ใช้ `_bcrypt_safe()` ในการ hash/verify
2. อัปเกรดแพ็กเกจ `bcrypt` และ `passlib` ภายใน venv ตามคำสั่งที่ให้
3. รีสตาร์ทเซิร์ฟเวอร์และทดสอบทั้ง `/register_organization` และ `/login` ให้ผ่าน

