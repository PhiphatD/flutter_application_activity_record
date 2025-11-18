## เป้าหมาย
- จัดระเบียบโฟลเดอร์/ไฟล์ภายใต้ `lib/screens/employee_screens` ให้ค้นหาและดูแลรักษาง่าย
- ปรับชื่อ/ตำแหน่งไฟล์ให้สอดคล้องตามฟีเจอร์ และอัปเดต import ที่เกี่ยวข้องทั้งหมด

## โครงสร้างใหม่ (ตามฟีเจอร์)
- `employee_screens/main/employee_main_screen.dart`
- `employee_screens/activities/activity_feed_screen.dart`
- `employee_screens/activities/todo_screen.dart`
- `employee_screens/activities/activity_detail_screen.dart`
- `employee_screens/rewards/reward_screen.dart`
- `employee_screens/rewards/reward_detail_screen.dart`
- `employee_screens/rewards/redeemed_detail_screen.dart`
- `employee_screens/profile/profile_screen.dart`
- `employee_screens/widgets/activity_card.dart`
- `employee_screens/widgets/todo_activity_card.dart`

## รายการย้าย/เปลี่ยนชื่อไฟล์
- ย้าย `employee_main_screen.dart` → `main/employee_main_screen.dart`
- ย้าย `activity_feed_screen.dart` → `activities/activity_feed_screen.dart`
- ย้าย `activity_detail_screen.dart` → `activities/activity_detail_screen.dart`
- ย้าย `todo_screen.dart` → `activities/todo_screen.dart`
- ย้าย `reward_screen.dart`, `reward_detail_screen.dart`, `redeemed_detail_screen.dart` → `rewards/`
- ย้าย `profile_screen.dart` → `profile/profile_screen.dart`
- ย้าย `activity_card.dart`, `todo_activity_card.dart` → `widgets/`

## อัปเดต import ที่ได้รับผลกระทบ
- `employee_main_screen.dart` (เดิมที่ `employee_screens/`) เปลี่ยนเป็น
  - `import 'activities/activity_feed_screen.dart';`
  - `import 'activities/todo_screen.dart';`
  - `import 'rewards/reward_screen.dart';`
  - อ้างอิง: `lib/screens/employee_screens/employee_main_screen.dart:5-7`

- `activity_feed_screen.dart`
  - `import 'activity_card.dart';` → `import '../widgets/activity_card.dart';`
  - `import 'profile_screen.dart';` → `import '../profile/profile_screen.dart';`
  - อ้างอิง: `lib/screens/employee_screens/activity_feed_screen.dart:3-4`

- `activity_card.dart`
  - `import 'activity_detail_screen.dart';` → `import '../activities/activity_detail_screen.dart';`
  - อ้างอิง: `lib/screens/employee_screens/activity_card.dart:3`

- `todo_screen.dart`
  - `import 'todo_activity_card.dart';` → `import '../widgets/todo_activity_card.dart';`
  - `import 'profile_screen.dart';` → `import '../profile/profile_screen.dart';`
  - อ้างอิง: `lib/screens/employee_screens/todo_screen.dart:3,5`

- `reward_screen.dart`
  - `import 'profile_screen.dart';` → `import '../profile/profile_screen.dart';`
  - `import 'reward_detail_screen.dart';` และ `import 'redeemed_detail_screen.dart';` คงเดิม (ไฟล์จะย้ายไปอยู่โฟลเดอร์เดียวกัน `rewards/`)
  - อ้างอิง: `lib/screens/employee_screens/reward_screen.dart:4-6`

- อื่น ๆ ที่อ้างอิงไฟล์ Employee จากภายนอก:
  - `organizer_screens/activities/activities_management_screen.dart` เปลี่ยน `import '../../employee_screens/activity_detail_screen.dart';` → `import '../../employee_screens/activities/activity_detail_screen.dart';`
  - อ้างอิง: `lib/screens/organizer_screens/activities/activities_management_screen.dart:5`
  - `login_screen.dart` เปลี่ยน `import 'employee_screens/employee_main_screen.dart';` → `import 'employee_screens/main/employee_main_screen.dart';`
  - อ้างอิง: `lib/screens/login_screen.dart:5`

## เหตุผลและมาตรฐานการตั้งชื่อ
- ใช้ `lower_snake_case` สม่ำเสมอ
- แยกตามฟีเจอร์ชัดเจน: `main/`, `activities/`, `rewards/`, `profile/`, `widgets/`
- ลดการพึ่งพาข้ามไฟล์แบบกระจัดกระจายด้วยการจัดรวม widgets ไว้ที่เดียว

## การทดสอบหลังย้าย
- รัน `flutter analyze` ตรวจสอบความถูกต้องของ import/การอ้างอิง
- เปิดแอปและทดสอบการนำทาง:
  - Login → EmployeeMainScreen
  - Tab Activity: เปิด ActivityFeedScreen และทดสอบการ์ดไป ActivityDetailScreen
  - Tab To do: แสดงรายการตามกรองและการ์ดจาก `todo_activity_card`
  - Tab Reward: เปิด RewardDetail และ RedeemedDetail ได้
  - หน้าโปรไฟล์เข้าถึงได้จาก AppBar ทุกแท็บ

## ทางเลือกเพิ่มเติม (ขออนุมัติหากต้องการ)
- แยกโมเดลที่ซ้ำ ๆ (`_Activity`, `_TodoActivity`, `_RewardItem`, `_RedeemedItem`) ไป `employee_screens/models/` พร้อม type ที่ไม่เป็น private เพื่อใช้ข้ามไฟล์
- รวม formatter ของวันที่ไว้ใน helper เดียว เช่น `employee_screens/utils/date_format.dart`

## ขั้นตอนดำเนินการ
1) สร้างโฟลเดอร์ย่อยตามโครงสร้างใหม่
2) ย้ายไฟล์และอัปเดต import ตามรายการด้านบน
3) ปรับ import ภายนอก (organizer, login) ให้เข้ากับตำแหน่งใหม่
4) วิเคราะห์และทดสอบการนำทาง

กรุณายืนยันแผนนี้ เพื่อดำเนินการย้ายไฟล์และอัปเดต import ให้เรียบร้อย