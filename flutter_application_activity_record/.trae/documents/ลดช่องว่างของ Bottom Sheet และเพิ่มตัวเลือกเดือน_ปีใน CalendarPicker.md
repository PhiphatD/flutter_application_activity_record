## เป้าหมาย
- ลดพื้นที่ว่างของแผงเลือกวันที่ (Bottom Sheet) ให้กระชับขึ้น
- เพิ่มความสามารถให้กดเลือกเดือนและปีได้โดยตรงใน CalendarPicker
- รักษา UX ไม่ให้ปุ่ม “Use this date” ทับกับ Home Indicator

## การแก้ไข
1) ปรับ CalendarPicker
- ทำให้ชิพ “เดือน” และ “ปี” กดเลือกได้: เพิ่ม `_pickMonth()` และ `_pickYear()` เปิดเป็น Bottom Sheet เลือกเดือน (Grid 12 เดือน) และปี (List ปี 1900 → ปีปัจจุบัน)
- ลดช่องว่าง: ลด `padding` ของกรอบหลักจาก 12 → 8, ลดความสูงช่องวันจาก 40 → 36, ลดระยะระหว่างแถววันจาก 6 → 4

2) ปรับ Bottom Sheet ใน `organization_register_screen.dart`
- ลด `heightFactor` จาก 0.7 → 0.6
- ปรับ `padding` ด้านในให้เล็กลง และยังใช้ `SafeArea(bottom: true)` พร้อม `viewPadding.bottom + 8` เพื่อกันทับกับ Home Indicator

## ผลลัพธ์
- แผงเลือกวันที่กระชับขึ้น ไม่เว้นช่องเกินจำเป็น
- ผู้ใช้สามารถเปลี่ยนเดือน/ปีได้สะดวก โดยตรง
- ปุ่ม “Use this date” อยู่เหนือแถบ Home Indicator

## ทดสอบ
- เปิดช่อง Start Date → เลือกเดือน/ปีได้จาก Bottom Sheet ของ CalendarPicker และวันย้อนหลังได้
- ตรวจสอบการกดปุ่มยืนยันไม่ทับ gesture bar
- รัน `flutter analyze` ให้ผ่าน