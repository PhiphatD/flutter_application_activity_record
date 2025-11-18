## เป้าหมาย
- ใช้หน้าจอ Create Activity เดียวกันสำหรับแก้ไข โดยดึงข้อมูลจาก id มากรอกในฟอร์ม
- ปุ่มท้ายหน้าเปลี่ยนเป็น Save เมื่ออยู่โหมดแก้ไข

## วิธีปรับ
- ปรับ `CreateActivityScreen` ให้รับพารามิเตอร์ใหม่:
  - `initialData: Map<String, dynamic>?` (โครงสร้างเดียวกับผลลัพธ์ `_buildResult()`)
  - `isEdit: bool` (ค่าเริ่ม false)
- ใน `initState()` ของ CreateActivity:
  - ถ้ามี `initialData` ให้เติมค่าให้ `TextEditingController` และตัวแปรเลือกวันที่/เวลา (`_useRange`, `_dateRange`, `_multipleDates`, `_startTime`, `_endTime`, `_type`, ฯลฯ)
- ปรับปุ่มล่าง: ถ้า `isEdit==true` เปลี่ยนข้อความเป็น `Save` และยังคืน `result` เดิมผ่าน `Navigator.pop`

- สร้าง/ปรับ `EditActivityScreen` เป็น wrapper:
  - โหลด mock data ตาม id แล้วเรียก `CreateActivityScreen(initialData: ..., isEdit: true)`
  - Mock รวมฟิลด์ ACTIVITY, ORGANIZER, SESSIONS ให้ครบ

## การเชื่อมต่อ
- ใน `activities_management_screen.dart` มี `onEdit` อยู่แล้ว → ไม่ต้องแก้, จะแสดงหน้า Create ในโหมดแก้ไข

## ทดสอบ
- เปิดหน้า Management → กด Edit ในแต่ละกิจกรรม → ค่าถูกเติมในฟอร์มครบ, ปุ่มล่างเป็น Save
- รัน `flutter analyze` ตรวจ error

กรุณายืนยัน เพื่อให้ผมลงมือปรับสองไฟล์นี้ตามแผน