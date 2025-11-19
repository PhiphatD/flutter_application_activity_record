## ภาพรวมการเปลี่ยนแปลง
- แทนที่โค้ดใน `lib/screens/auth/login_screen.dart` และ `lib/screens/auth/register/organization_register_screen.dart` ด้วยเวอร์ชันที่เรียก API จริงตามที่ให้มา
- ใช้ `package:http/http.dart` สำหรับยิง REST API และ `dart:convert` สำหรับแปลง JSON
- ตั้งค่า `apiUrl` เป็น `http://10.0.2.2:8000` สำหรับ Android Emulator (iOS Simulator ใช้ `http://localhost:8000`; อุปกรณ์จริงควรใช้ IP ของเครื่องที่รันเซิร์ฟเวอร์)

## รายละเอียดการปรับ LoginScreen
- Import: `http` และ `dart:convert` เพิ่มตามตัวอย่าง
- เมธอด `_login()`
  - POST ไปยัง `POST /login` ด้วย JSON `{ email, password }`
  - สำเร็จ (`200`): อ่าน `role` จาก response และเรียก `_navigateToUserMainScreen(role)` เพื่อไปหน้าหลักตามบทบาท
  - ไม่สำเร็จ: อ่าน `detail` จาก response หรือแสดงข้อความค่าเริ่มต้น พร้อม SnackBar แจ้งเตือน และคืน `_isLoading = false`
  - จัดการข้อผิดพลาดเครือข่าย: แสดง SnackBar ว่าเชื่อมต่อเซิร์ฟเวอร์ไม่ได้
- นำทางตามบทบาท
  - `admin/organizer` → `OrganizerMainScreen`
  - `employee` → `EmployeeMainScreen`

## รายละเอียดการปรับ OrganizationRegisterScreen
- Import: `http` และ `dart:convert` เพิ่มตามตัวอย่าง
- เมธอด `_registerOrganization()` ตรวจฟอร์ม + รหัสผ่าน แล้วเปิด Dialog ยืนยัน
- เมื่อกดยืนยันใน Dialog → `_performRegistration()`
  - POST ไปยัง `POST /register_organization` ด้วยข้อมูลบริษัทและแอดมิน (รหัสผ่านถูกแฮชที่ฝั่งเซิร์ฟเวอร์)
  - สำเร็จ (`200`): ไปหน้า `RegistrationSuccessfulScreen` และเคลียร์สแตกการนำทาง
  - ไม่สำเร็จ: อ่าน `detail` จาก response หรือแสดงข้อความค่าเริ่มต้น พร้อม SnackBar และคืน `_isLoading = false`
  - จัดการข้อผิดพลาดเครือข่าย: แสดง SnackBar ว่าเชื่อมต่อเซิร์ฟเวอร์ไม่ได้

## การตรวจสอบความพร้อมของโปรเจ็กต์
- `pubspec.yaml` มี dependency `http` อยู่แล้ว ไม่ต้องเพิ่ม
- ยืนยันตำแหน่งไฟล์ปลายทางถูกต้อง:
  - `lib/screens/auth/login_screen.dart`
  - `lib/screens/auth/register/organization_register_screen.dart`
  - หน้าหลัก:
    - `lib/screens/organizer_screens/main/organizer_main_screen.dart`
    - `lib/screens/employee_screens/main/employee_main_screen.dart`
- Backend FastAPI พร้อมใช้งาน:
  - `/login` ส่งคืน `{ message, role, emp_id, name }` หรือ `HTTP 400` พร้อม `detail`
  - `/register_organization` สร้างองค์กร + ผู้ดูแล และส่งคืน `{ message, emp_id }` หรือ `HTTP 400` พร้อม `detail`

## ขั้นตอนการทดสอบ
- เปิด Python Server ด้วย `uvicorn main:app --reload --host 0.0.0.0 --port 8000` ในโฟลเดอร์ `lib/backend_api`
- รันแอป Flutter บนอีมูเลเตอร์/อุปกรณ์
- ทดสอบการลงทะเบียนองค์กร: กรอกข้อมูล → ยืนยัน → ไปหน้า Success
- กลับไปหน้า Login: ใช้อีเมล/รหัสผ่านที่ลงทะเบียน → เข้าสู่ระบบสำเร็จและนำทางตามบทบาท
- ทดสอบกรณีผิดพลาด: รหัสผ่านผิด, อีเมลซ้ำ, เซิร์ฟเวอร์ปิด → ระบบแสดง SnackBar ตามที่กำหนด

## หมายเหตุเพิ่มเติม
- หากจะใช้งานบน iOS Simulator หรืออุปกรณ์จริง แนะนำปรับ `apiUrl` ให้เหมาะสม (`localhost`/IP เครื่อง)
- ในอนาคตสามารถเพิ่มการเก็บ token/role ใน `SharedPreferences` เพื่อทำ auto-login จาก `SplashScreen`

## สิ่งที่จะลงมือทำเมื่อได้รับยืนยัน
1. แทนที่เนื้อหาไฟล์ `login_screen.dart` ด้วยเวอร์ชันที่เรียก API จริง
2. แทนที่เนื้อหาไฟล์ `organization_register_screen.dart` ด้วยเวอร์ชันที่เรียก API จริง
3. ตรวจ build และรันทดสอบตามขั้นตอนที่ระบุ