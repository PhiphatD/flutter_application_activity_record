## สาเหตุ
- HTTP 500: ใช้รูป `NetworkImage('https://i.pravatar.cc/150?img=32')` หลายจุด ทำให้โหลดล้มเหลวและโยน exception
- Dropdown error: ค่าเริ่มต้นของ Department เป็น 'All Departments' แต่ตัวเลือกในฟอร์มมีเฉพาะ 'IT/HR/Marketing'

## แผนแก้ไข
- เปลี่ยน avatar เป็น placeholder ปลอดภัยในทุก header ที่ใช้รูป network:
  - ใช้ `CircleAvatar(child: Icon(Icons.person))` แทน `backgroundImage: NetworkImage(...)`
  - ไฟล์ที่จะปรับ: Management header, Participants list header, Participants details header
- แก้ dropdown Department ใน `activity_create_screen.dart`:
  - เพิ่มรายการตัวเลือก: `['All Departments','IT','HR','Marketing']`
  - ถ้า `initialData['DEP_ID']` ไม่อยู่ในรายการ ให้ fallback เป็น `'All Departments'`

## การทดสอบ
- เปิดหน้า Organizer ทั้งสองและหน้า Create/Edit → ไม่มี HTTP 500 spam
- เปิด Edit Activity ที่มี `DEP_ID='All Departments'` → dropdown ทำงานปกติ

ขออนุมัติแผนนี้เพื่อดำเนินการแก้ไขทันที