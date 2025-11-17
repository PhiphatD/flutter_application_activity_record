## เป้าหมาย
- เปลี่ยนพื้นหลังของหน้าหลัก (`EmployeeMainScreen`) ในโฟลเดอร์ `employee_screens` ให้เป็นสี `#E2F3FF` ที่ความโปร่งใส 30%

## วิธีแก้ไข
- แก้ไขไฟล์ `lib/screens/employee_screens/employee_main_screen.dart`
- ตั้งค่า `backgroundColor` ของ `Scaffold` เป็น `const Color(0x4DE2F3FF)` ซึ่งเท่ากับ `E2F3FF` ที่ alpha ≈ 30%
- ไม่แก้ไขหน้าลูก (ActivityFeed/Todo/Reward) และไม่เปลี่ยนสี BottomNavigationBar ตามคำขอ (เฉพาะ BG หน้าหลัก)

## ทดสอบ
- เปิดหน้า EmployeeMainScreen เพื่อเห็นพื้นหลังใหม่
- ตรวจสอบว่าสีพื้นหลังปรากฏ เมื่อหน้าลูกไม่ได้ทับด้วยสีทึบทั้งหมด; หากหน้าลูกมีพื้นหลังสีขาว จะเห็นเฉพาะบริเวณที่ไม่ถูกทับ เช่น ระหว่างคอมโพเนนต์หรือหลัง BottomNavigationBar