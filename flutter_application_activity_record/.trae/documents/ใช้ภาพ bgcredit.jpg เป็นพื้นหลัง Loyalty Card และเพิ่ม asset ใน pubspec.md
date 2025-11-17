## เป้าหมาย
- เปลี่ยนพื้นหลังของ `_buildLoyaltyCard()` ให้ใช้ภาพ `assets/images/bgcredit.jpg`
- ลงทะเบียน asset ใน `pubspec.yaml` ถ้ายังไม่ได้เพิ่ม

## สิ่งที่จะทำ
- เพิ่ม `assets/images/bgcredit.jpg` ในส่วน `flutter.assets` ของ `pubspec.yaml`
- ปรับ `BoxDecoration` ใน `_buildLoyaltyCard()` จาก gradient เป็น `DecorationImage` ด้วย `AssetImage('assets/images/bgcredit.jpg')` และเพิ่ม `colorFilter` เบาๆ เพื่อให้อ่านตัวหนังสือสีขาวชัดเจน

## รายละเอียดโค้ด
- `pubspec.yaml`: เพิ่มบรรทัด `- assets/images/bgcredit.jpg` ใต้ assets ที่มีอยู่แล้ว
- `lib/screens/employee_screens/reward_screen.dart` → `_buildLoyaltyCard()`
  - แก้ `decoration: BoxDecoration(...)` เป็น
    - `image: DecorationImage(image: AssetImage('assets/images/bgcredit.jpg'), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.2), BlendMode.darken))`
    - คง `borderRadius: BorderRadius.circular(16.0)` เดิม

## ทดสอบ
- เปิดหน้า Reward แล้วตรวจว่าการ์ดแสดงภาพพื้นหลังและตัวอักษรยังอ่านง่าย
- หากภาพไม่พบ ให้ตรวจว่ามีไฟล์ใน `assets/images/bgcredit.jpg` ตรงกับ `pubspec.yaml`