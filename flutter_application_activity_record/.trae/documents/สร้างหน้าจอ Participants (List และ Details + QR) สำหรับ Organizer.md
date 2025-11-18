## เป้าหมาย
- หน้าที่ 1: รายการกิจกรรมของ Organizer เพื่อเข้าไปจัดการผู้เข้าร่วม
- หน้าที่ 2: รายชื่อผู้เข้าร่วมและการสแกน QR เพื่อเช็คชื่อเข้าร่วม

## โครงสร้างไฟล์
- `organizer_screens/participants/activities_participants_list_screen.dart` — รายการกิจกรรมของฉันเท่านั้น
- `organizer_screens/participants/participants_details_screen.dart` — รายละเอียดกิจกรรม + Tabs Registered/Joined + FAB QR
- ปรับ `organizer_screens/participants/participants_screen.dart` ให้เรียกหน้ารายการใหม่

## รายการข้อมูลและ Mapping
- List Screen:
  - แสดงการ์ดกิจกรรม: `ACT_NAME`, `ACT_TYPE`, `ACT_POINT`, `LOCATION`, `START_TIME`, `ACT_ISCOMPULSORY`
  - กรองเฉพาะ `ORG_ID = Current_User` (mock current orgId=1 ชั่วคราว)
  - แตะการ์ด → ไปหน้า Details
- Details Screen:
  - ส่วนหัว: วัน/สถานที่, ข้อความ Description พร้อมปุ่ม Read more
  - Tabs: Registered (จาก REGISTRATION), Joined (จาก CHECKIN)
  - รายชื่อ: `EMP_IMAGE`, `EMP_NAME` ตามตัวอย่าง
  - FAB สแกน QR: stub ด้วย dialog รับ `EMP_ID` แล้ว Insert ลงรายการ CHECKIN และย้ายผู้ใช้จาก Registered → Joined

## สไตล์
- ใช้ธีม Organizer `organizerBg`, ฟอนต์ `GoogleFonts.poppins`
- การ์ดคล้ายหน้า Management แต่ไม่มีปุ่ม Edit/Delete

## การเชื่อมต่อ
- `OrganizerMainScreen` ยังใช้ `ParticipantsScreen` ตามเดิม; ภายใน `ParticipantsScreen` จะเรียกหน้ารายการใหม่

## การทดสอบ
- `flutter analyze` ตรวจ error
- เปิด Organizer → Participants → เลือกกิจกรรม → หน้ารายชื่อ → ใช้ FAB เพิ่มผู้เข้าร่วมไปยัง Joined

กรุณายืนยัน เพื่อให้ผมสร้างสองหน้าจอและเชื่อมต่อการนำทาง พร้อม stub QR scanner ตามที่ระบุ