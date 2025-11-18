## เป้าหมาย
- ปรับ mock data ในหน้ารายการ Participants ให้มีตัวอย่างกิจกรรมทั้งโหมด Registered และ Joined
- แสดงจำนวน Registered และ Joined บนการ์ดกิจกรรมตามตัวอย่างภาพ
- ปรับหน้า Details ให้มีผู้เข้าร่วมที่ Joined อย่างน้อย 1 คนเพื่อเป็นตัวอย่าง

## การเปลี่ยนแปลง
1. `activities_participants_list_screen.dart`
- ขยายโมเดล `_Activity` ให้มี `registeredCount` และ `joinedCount`
- อัปเดต `_activities` ให้มีอย่างน้อย 2 รายการของ `orgId == 1`:
  - รายการที่ "ยังไม่เริ่ม" (Registered) พร้อม `registeredCount > 0`, `joinedCount >= 0`
  - รายการที่ "เริ่มแล้ว/สิ้นสุด" (Joined) พร้อมจำนวนเข้าร่วม
- ปรับ `_ActivityCard` ให้แสดงบรรทัด "Registered: X • Joined: Y" ใต้ข้อมูลสถานที่/เวลา

2. `participants_details_screen.dart`
- เพิ่มผู้เข้าร่วมใน `_joined` เริ่มต้น 1 คน เพื่อเป็นตัวอย่างโหมด Joined

## ไม่เปลี่ยนโครงสร้างสร้างกิจกรรม
- `activity_create_screen.dart` ไม่ต้องแก้ เพราะเป็นฟอร์มสร้างกิจกรรม ไม่มีข้อมูลผู้เข้าร่วมโดยตรง

## การทดสอบ
- โหมด Registered: เห็นกิจกรรมอนาคตและแสดงจำนวน Registered/Joined บนการ์ด
- โหมด Joined: เห็นกิจกรรมที่เริ่มแล้ว/จบแล้ว และในหน้ารายละเอียดมีรายชื่อ Joined อย่างน้อย 1 คน

ขออนุมัติให้ดำเนินการปรับตามแผนนี้