## เป้าหมาย
- ทำให้หัวข้อ “Employee ID” ไม่เลื่อนขึ้นไปทับกับชื่อ AppBar “My Profile” ขณะเลื่อนหน้าจอ

## แนวทางที่เลือก (เรียบง่ายและชัดเจน)
- ย้ายหัวข้อ “Employee ID” (ตัวหนังสือ + หมายเลข + เส้นแบ่ง) ไปอยู่ใน `AppBar.bottom` ด้วย `PreferredSize` ให้มันถูกตรึงอยู่ใต้ชื่อ “My Profile” ตลอด และไม่ทับกัน
- เอา Section “Employee ID” ออกจากส่วน `SingleChildScrollView` ใน body เพื่อไม่ให้มีซ้ำและแก้เคลื่อนทับ
- ปรับ padding ด้านบนของ `SingleChildScrollView` ให้เหมาะสมหลังย้ายหัวข้อขึ้น AppBar

## รายการแก้โค้ด
- แก้ที่ไฟล์ `lib/screens/employee_screens/profile/profile_screen.dart`

### 1) เพิ่มหัวข้อ Employee ID ใน AppBar
- ที่ส่วน `AppBar(...)` เพิ่ม:
```dart
bottom: PreferredSize(
  preferredSize: const Size.fromHeight(72),
  child: Column(
    children: [
      const Text(
        'Employee ID',
        style: TextStyle(fontSize: 16, color: Color(0xFF375987)),
      ),
      Text(
        empId,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF375987),
        ),
      ),
      const SizedBox(height: 8),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 180),
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFF375987).withOpacity(0.2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ],
  ),
),
```

### 2) ลบหัวข้อ Employee ID ออกจาก body ที่เลื่อน
- เอาบล็อกส่วนนี้ออกจาก `SingleChildScrollView`:
```dart
const Text('Employee ID', ...),
Text(empId, ...),
Container(height: 4, ...),
const SizedBox(height: 20),
```
อ้างอิงช่วงบรรทัดโดยประมาณ: 191–216 ของไฟล์ปัจจุบัน

### 3) ปรับ padding ของ `SingleChildScrollView`
- เปลี่ยน `padding: const EdgeInsets.symmetric(vertical: 20)` เป็น `padding: const EdgeInsets.only(bottom: 20)` หรือคงไว้ `vertical: 20` ก็ได้ หากต้องการระยะห่างด้านบนเล็กน้อย

### 4) (ทางเลือก) ครอบ `body` ด้วย `SafeArea`
- ถ้าต้องการความปลอดภัยกับรอยบาก/สถานะแถบ ให้ใช้:
```dart
body: SafeArea(
  child: Stack(
    children: [...],
  ),
),
```

## ผลลัพธ์ที่คาดหวัง
- ขณะเลื่อนหน้า “Employee ID” จะถูกตรึงอยู่ใต้ “My Profile” ไม่ทับกัน
- เนื้อหาอื่น ๆ ยังคงเลื่อนได้ตามปกติ

## การทดสอบ
- รันแอป ไปหน้า Profile และเลื่อนขึ้น/ลง ตรวจว่า “Employee ID” อยู่ใต้ AppBar ตลอด
- ตรวจสอบการตอบสนองบนอุปกรณ์ที่มีรอยบาก/สถานะแถบ หากใช้ `SafeArea` จะไม่เกิดปัญหาทับสถานะแถบ

หากโอเคกับแผนนี้ จะดำเนินการแก้โค้ดตามที่ระบุและส่งผลลัพธ์ให้ตรวจสอบทันที