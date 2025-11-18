## เป้าหมาย
- ใช้ email/password จำลองเพื่อล็อกอิน และกำหนดบทบาทเป็น employee หรือ organizer

## แนวทางแก้
1. เพิ่มชุดข้อมูลผู้ใช้ mock ในไฟล์ `login_screen.dart` เช่น:
   - employee@company.com / 123456 → role: employee
   - organizer@company.com / 123456 → role: organizer
2. ปรับเมธอด `_mockLoginAndGetRole(email, password)` ให้ตรวจสอบกับ mock data และส่ง role กลับ
3. ใน `_login()` แสดงข้อความผิดพลาดเมื่อข้อมูลไม่ถูกต้องด้วย SnackBar

## การทดสอบ
- ใส่ `employee@company.com` และ `123456` → ไปหน้า EmployeeMainScreen
- ใส่ `organizer@company.com` และ `123456` → ไปหน้า OrganizerMainScreen
- ใส่ข้อมูลผิด → แสดง SnackBar แจ้งล็อกอินไม่สำเร็จ

ขออนุมัติให้ดำเนินการปรับตามแผนนี้