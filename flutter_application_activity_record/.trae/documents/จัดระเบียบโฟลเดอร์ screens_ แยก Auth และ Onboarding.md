## เป้าหมาย
- ย้ายไฟล์หน้าจอที่อยู่นอก `employee_screens` และ `organizer_screens` ไปอยู่ในโครงสร้างใหม่ให้เข้าใจง่าย
- ไม่เปลี่ยนพฤติกรรมหน้าจอ, ปรับเฉพาะตำแหน่งไฟล์และ import path

## โครงสร้างใหม่
- `lib/screens/auth/`
  - `login_screen.dart`
  - `register/organization_register_screen.dart`
  - `register/registration_successful_screen.dart`
  - `password/forgot_password_screen.dart`
  - `password/verify_otp_screen.dart`
  - `password/reset_password_screen.dart`
- `lib/screens/onboarding/`
  - `onboarding_screen.dart`
  - `splash_screen.dart`

## ไฟล์ที่จะย้าย
- จาก `lib/screens/`
  - `login_screen.dart` → `lib/screens/auth/login_screen.dart`
  - `organization_register_screen.dart` → `lib/screens/auth/register/organization_register_screen.dart`
  - `registration_successful_screen.dart` → `lib/screens/auth/register/registration_successful_screen.dart`
  - `forgot_password_screen.dart` → `lib/screens/auth/password/forgot_password_screen.dart`
  - `verify_otp_screen.dart` → `lib/screens/auth/password/verify_otp_screen.dart`
  - `reset_password_screen.dart` → `lib/screens/auth/password/reset_password_screen.dart`
  - `onboarding_screen.dart` → `lib/screens/onboarding/onboarding_screen.dart`
  - `splash_screen.dart` → `lib/screens/onboarding/splash_screen.dart`

## ปรับ import ที่เกี่ยวข้อง
- `auth/login_screen.dart`
  - เปลี่ยน `import 'organization_register_screen.dart';` → `import 'register/organization_register_screen.dart';`
  - เปลี่ยน `import 'forgot_password_screen.dart';` → `import 'password/forgot_password_screen.dart';`
- `auth/register/organization_register_screen.dart`
  - เปลี่ยน `import 'login_screen.dart';` → `import '../login_screen.dart';`
- `auth/register/registration_successful_screen.dart`
  - เปลี่ยน `import 'login_screen.dart';` → `import '../login_screen.dart';`
- `auth/password/forgot_password_screen.dart`
  - เปลี่ยน `import 'verify_otp_screen.dart';` → `import 'verify_otp_screen.dart';` (เหมือนเดิมแต่ path ใหม่อยู่โฟลเดอร์เดียวกัน)
- `auth/password/verify_otp_screen.dart`
  - เปลี่ยน `import 'reset_password_screen.dart';` → `import 'reset_password_screen.dart';` (โฟลเดอร์เดียวกัน)
- `onboarding/onboarding_screen.dart`
  - เปลี่ยน `import 'login_screen.dart';` → `import '../auth/login_screen.dart';`
- `onboarding/splash_screen.dart`
  - เปลี่ยน `import 'onboarding_screen.dart';` → `import 'onboarding_screen.dart';` (โฟลเดอร์เดียวกัน)
  - เปลี่ยน `import 'login_screen.dart';` → `import '../auth/login_screen.dart';`

## อ้างอิงที่พบในโค้ด
- `lib/screens/login_screen.dart:6` นำเข้า `forgot_password_screen.dart`
- `lib/screens/organization_register_screen.dart:3` นำเข้า `login_screen.dart`
- `lib/screens/splash_screen.dart:3-4` นำเข้า `onboarding_screen.dart` และ `login_screen.dart`
- `lib/screens/registration_successful_screen.dart:4` นำเข้า `login_screen.dart`
- `lib/screens/onboarding_screen.dart:5` นำเข้า `login_screen.dart`
- `lib/screens/forgot_password_screen.dart:4` นำเข้า `verify_otp_screen.dart`
- `lib/screens/verify_otp_screen.dart:4` นำเข้า `reset_password_screen.dart`

## ขั้นตอนดำเนินการ
1. สร้างโฟลเดอร์ใหม่ `auth/`, `auth/register/`, `auth/password/`, `onboarding/`
2. ย้ายไฟล์ตามรายการด้านบน
3. ปรับ import path ให้ถูกต้องทุกไฟล์ที่อ้างอิง
4. ตรวจสอบการ build และ navigation ว่ายังทำงานครบ

## การทดสอบหลังแก้
- เปิดแอปเข้าสู่หน้า `Splash` → `Onboarding` → `Login` ได้ตามเดิม
- จาก `Login` ไป `Forgot Password` → `Verify OTP` → `Reset Password` ได้ครบ
- จาก `Login` ไป `Organization Register` และ `Registration Successful` ทำงานปกติ

ยืนยันให้ดำเนินการย้ายโครงสร้างและปรับ import ตามแผนนี้หรือไม่?