## เป้าหมาย
- ให้ฝั่ง Employee ใช้พื้นหลังฟ้าอ่อนจาง
- ให้ฝั่ง Organizer ใช้พื้นหลังเหลืองอ่อนจาง
- ทำให้สไตล์สอดคล้องกันทุกหน้าหลักและสกรีนย่อยสำคัญ

## สีที่ใช้
- Employee: `Color(0xFFF3F7FF)` (ฟ้าอ่อนจาง)
- Organizer: `Color(0xFFFFF6CC)` (เหลืองอ่อนจาง)
- ChoiceChip ที่ทำแล้วคงเดิม: เลือกอยู่เป็นเหลือง `Color(0xFFFFD600)`

## ไฟล์ที่จะปรับ
- Employee
  - `lib/screens/employee_screens/main/employee_main_screen.dart` → เปลี่ยน `Scaffold.backgroundColor` เป็น `employeeBg`
  - `lib/screens/employee_screens/activities/activity_feed_screen.dart` → เปลี่ยน `Scaffold.backgroundColor` เป็น `employeeBg`
  - `lib/screens/employee_screens/activities/todo_screen.dart` → เปลี่ยน `Scaffold.backgroundColor` เป็น `employeeBg`
  - `lib/screens/employee_screens/rewards/reward_screen.dart` → เปลี่ยน `Scaffold.backgroundColor` เป็น `employeeBg`
- Organizer
  - `lib/screens/organizer_screens/main/organizer_main_screen.dart` → เปลี่ยน `Scaffold.backgroundColor` เป็น `organizerBg`
  - `lib/screens/organizer_screens/activities/activities_management_screen.dart` → เปลี่ยน `Scaffold.backgroundColor` เป็น `organizerBg`
  - `lib/screens/organizer_screens/participants/participants_screen.dart` → เปลี่ยน `Scaffold.backgroundColor` เป็น `organizerBg`
  - (ตัวเลือก) `lib/screens/organizer_screens/profile/organizer_profile_screen.dart` → ปรับ gradient เป็นเหลืองอ่อน→ขาว: `[Color(0xFFFFF6CC), Colors.white]`

## วิธีจัดการสี
- เพิ่มไฟล์เล็ก `lib/theme/app_colors.dart` เก็บค่าสี:
  - `const employeeBg = Color(0xFFF3F7FF);`
  - `const organizerBg = Color(0xFFFFF6CC);`
- import และใช้แทนค่าคงที่ในหน้าต่าง ๆ เพื่อลดการซ้ำและควบคุมธีมได้ง่าย

## การทดสอบ
- รัน `flutter analyze` ตรวจสอบ error
- เปิดหน้าหลัก Employee และ Organizer ตรวจสอบว่าพื้นหลังเป็นไปตามที่ต้องการ
- ตรวจดูว่าการ์ดและคอนโทรลอื่น ๆ ยังอ่านง่ายบนพื้นหลังใหม่

กรุณายืนยัน เพื่อให้ผมเพิ่มไฟล์สีธีมและปรับพื้นหลังในหน้าที่เกี่ยวข้องตามรายการข้างต้น