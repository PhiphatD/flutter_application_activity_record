## เป้าหมาย
- เพิ่มข้อมูลจำลองของกิจกรรมในหน้ารายละเอียด (ActivityDetailScreen) ให้รองรับรหัสกิจกรรมจากหน้า Management: 1001, 1002, 1003, 1004

## วิธีทำ
- แก้ไฟล์ `lib/screens/employee_screens/activities/activity_detail_screen.dart`
- เพิ่มรายการใน `_mockDetailDatabase` สำหรับคีย์ '1001', '1002', '1003', '1004' โดยใช้ข้อมูลจากหน้า Management:
  - 1001: Leadership Seminar — type Seminar, point 10, location HQ Room A, วันที่ตรงกับ session (add 2 days 3 hours)
  - 1002: Agile Workshop — type Workshop, point 15, location HQ Room B, วันที่ add 5 days
  - 1003: Tech Trends 2025 — type Seminar, point 8, location Auditorium, วันที่ add 1 day 1 hour
  - 1004: Security Best Practices — type Workshop, point 20, location Lab 2, วันที่ add 7 days
- เติมฟิลด์อื่น ๆ ให้ครบ เช่น guestSpeaker, eventHost, organizerContact, department, participationFee, description, status (upcoming)

## การทดสอบ
- กดการ์ดในหน้า Management เพื่อเปิดรายละเอียดแต่ละ id (1001–1004) แล้วตรวจว่าแสดงข้อมูลได้ครบถ้วน
- รัน `flutter analyze` เพื่อตรวจว่าไม่มี error syntax

กรุณายืนยัน เพื่อให้ผมเพิ่ม mock data ตามรายการด้านบน