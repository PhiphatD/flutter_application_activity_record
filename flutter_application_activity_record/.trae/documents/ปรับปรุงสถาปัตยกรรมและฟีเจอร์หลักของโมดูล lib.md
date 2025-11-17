## ภาพรวมงานที่จะทำ

* จัดระเบียบโครงสร้างโค้ด Flutter ภายใต้ `lib/` ให้ชัดเจนและลดการซ้ำซ้อน

* เพิ่มชั้นข้อมูล (Repository/Service) สำหรับกิจกรรมและผู้ใช้ พร้อม Mock ที่แยกไฟล์

* ปรับระบบนำทางเป็น Named Routes และเพิ่ม Route Guard สำหรับ Onboarding/Login

* วางระบบจัดการ state ที่เบาและเหมาะกับโปรเจ็ค (เช่น `ChangeNotifier`/`provider`)

* ยกระดับ UX: รวมสไตล์ที่ใช้ร่วมกัน, คง Fonts จาก Theme, จัดระเบียบวัน/เวลา

* เพิ่มการทดสอบพื้นฐาน (navigation, grouping/filtering, widget render)

## Phase 1: Clean-up & โครงสร้าง

* เปลี่ยนชื่อคลาสที่ซ้ำกัน: `employee_screens/activity_card.dart` → `ActivityFeedCard`, `todo_activity_card.dart` → `TodoActivityCard`

* ย้าย `enum ActivityStatus` และโมเดลกิจกรรมไปไว้ใน `lib/models/activity.dart` ให้ใช้ร่วมกัน

* แยกสไตล์ร่วมเป็น `lib/ui/styles.dart` (สี, spacing, ขนาดตัวอักษร) และใช้ Theme แทนการใส่ `GoogleFonts` รายจุด

* ย้าย Mock data ออกจากหน้าจอไปไว้ที่ `lib/data/mock/` เพื่อให้ UI ไม่พึ่งข้อมูลภายใน

## Phase 2: Routing & Guard

* ใช้ `MaterialApp.routes` และ `onGenerateRoute` เพื่อจัดการเส้นทางแบบ Named

* เพิ่ม Route Guard: Splash ตรวจ `SharedPreferences` → ส่งไป Onboarding หรือ Login อย่างชัดเจน

* รวมการนำทางหลังสมัครองค์กร/รีเซ็ตรหัสผ่านให้กลับสู่ Login ด้วย `Navigator.pushNamedAndRemoveUntil`

## Phase 3: Data Layer (Mock → API-ready)

* สร้าง `ActivityRepository` (get list, get detail, register/cancel) โดยเริ่มจาก Mock

* สร้าง `AuthService` (login, role, session) พร้อมพื้นที่ต่อ API ภายหลัง

* กำหนดสัญญา method และ model ที่เป็นหนึ่งเดียวระหว่าง Feed/Todo/Detail

## Phase 4: State Management

* ใช้ `provider` + `ChangeNotifier` สำหรับ: ActivityListState, ActivityDetailState, AuthState

* เก็บ Favorites และสถานะการลงทะเบียนด้วย `SharedPreferences` (key ต่อผู้ใช้)

* ปรับหน้าจอให้ subscribe กับ state แทนการถือ List ภายใน

## Phase 5: UX/Feature

* ปรับการจัดกลุ่มกิจกรรมใน Feed และการแสดงหัวข้อวันที่ให้สอดคล้องกันทั้งสองหน้า

* ทำให้ Todo แสดงสถานะจริง (Upcoming/Attended/Unattended) จาก repository เดียวกัน

* ปรับ Profile ให้ QR refresh ใช้ service และรองรับรูป/avatar จากโปรไฟล์จริง

## Phase 6: i18n & Validation

* เพิ่ม `flutter_localizations` และโครงสร้างข้อความเพื่อรองรับไทย/อังกฤษ

* รวม Validators ฟอร์ม (Register/Reset) ให้ใช้ซ้ำ และจัดการ error/feedback ที่สม่ำเสมอ

## Phase 7: Tests

* เขียน widget test สำหรับ Splash→Onboarding/Login และ BottomNav สลับแท็บ

* เขียน unit test สำหรับ grouping/filtering วันที่และคำนวณ relative date

* เขียน golden test สำหรับการ์ดกิจกรรมหลัก

## ผลลัพธ์ที่คาดหวัง

* โค้ดอ่านง่าย แยกชั้นชัดเจน ลดความเสี่ยงจากชื่อคลาสซ้ำ

* พร้อมต่อยอดเชื่อม API จริงโดยแทบไม่ต้องแก้ UI มาก

* UX สอดคล้องทั้งระบบและรองรับการทดสอบได้ดี

