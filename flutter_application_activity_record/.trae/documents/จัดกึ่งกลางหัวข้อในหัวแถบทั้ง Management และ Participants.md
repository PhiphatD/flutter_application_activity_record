## เป้าหมาย
- ปรับโครงสร้างหัวแถบ (header/app bar) ให้ข้อความหัวข้ออยู่ตรงกลางจริง ทั้งหน้า Management และ Participants ตามภาพตัวอย่าง

## วิธีปรับ
- เปลี่ยนจาก Row เป็น Stack + Align เพื่อให้สามารถวางไอคอนซ้าย/ขวาโดยไม่ดึงหัวข้อให้เบี้ยว
- ขนาดคงที่ของ header เช่น height 56–64 เพื่อความสม่ำเสมอ
- สีและฟอนต์คงเดิม

## ไฟล์ที่จะปรับ
- `lib/screens/organizer_screens/activities/activities_management_screen.dart`
  - เมธอด `_buildCustomAppBar()` → โครงสร้างเป็น `SizedBox(height: 64, child: Stack(...))` โดย:
    - `Align(left)` วาง `CircleAvatar`
    - `Align(center)` วาง `Text('Management')`
    - `Align(right)` วาง `IconButton` แจ้งเตือน
- `lib/screens/organizer_screens/participants/activities_participants_list_screen.dart`
  - เมธอด `_buildHeader()` → ใช้ Stack + Align เช่นเดียวกัน วาง `Participants` ตรงกลาง, avatar ซ้าย, more/right menu ขวา
- (ตัวเลือก) `lib/screens/organizer_screens/participants/participants_details_screen.dart`
  - เมธอด `_buildHeader()` → ใช้ Stack + Align ให้หัวข้อ `Participants` อยู่กึ่งกลางด้วยโครงสร้างเดียวกัน เพื่อความสอดคล้องทุกหน้าภายใต้ Participants

## การทดสอบ
- `flutter analyze` ตรวจ error
- เปิดสองหน้าและตรวจว่าหัวข้ออยู่กึ่งกลาง แม้มีไอคอนทั้งสองข้าง

กรุณายืนยัน เพื่อให้ผมปรับสอง/สามเมธอดตามรายการให้หัวข้ออยู่กึ่งกลาง