## เป้าหมาย
- สมัครองค์กร: อนุญาตเลือกวันที่ย้อนหลัง (วันเริ่มงาน)
- สร้างกิจกรรม: ล็อกไม่ให้เลือกย้อนหลังเหมือนเดิม
- ปรับ UX/UI ปุ่ม “Use this date” ให้ไม่ทับ Gesture/Home Indicator ด้านล่าง

## แนวทางเทคนิค
- เพิ่มพารามิเตอร์ใหม่ใน `CalendarPicker`: `allowPast` (default: false)
  - ถ้า `allowPast == true` → แตะวันย้อนหลังได้
  - ถ้า `allowPast == false` → วันย้อนหลังถูก disable เหมือนปัจจุบัน
- ใน `organization_register_screen.dart`:
  - เรียก Bottom Sheet ด้วย `SafeArea(bottom: true)` และเพิ่ม padding ล่างตาม `MediaQuery.of(context).viewPadding.bottom + 12`
  - ส่ง `allowPast: true` เข้า `CalendarPicker`
- ในหน้าสร้างกิจกรรม (หากใช้ CalendarPicker): ไม่ส่งค่า → คงค่า default `allowPast: false`

## รายการแก้ไขไฟล์
1) `lib/screens/organizer_screens/activities/widgets/calendar_picker.dart`
- เพิ่มฟิลด์:
  - `final bool allowPast;` ใน `CalendarPicker`
  - กำหนดค่าใน constructor (ค่า default = false)
- ปรับ `_buildDayCell`:
  - `onTap: (!allowPast && isPast) ? null : () => _onTapDay(day)`
  - ปรับสีตัวอักษร/เส้นขอบเฉพาะกรณี `!allowPast && isPast`

2) `lib/screens/auth/register/organization_register_screen.dart`
- ใน `_openStartDatePicker()`:
  - ห่อเนื้อหา Bottom Sheet ด้วย `SafeArea(bottom: true)` และเพิ่ม padding ล่างเพื่อกันทับ Home Indicator
  - เรียก `CalendarPicker(mode: CalendarMode.multi, initialMulti: [...], onMultiChanged: ..., allowPast: true)`

## ผลลัพธ์ที่คาดหวัง
- ช่อง Start Date ในการสมัครสามารถเลือกย้อนหลังได้และใช้งานสะดวก ปุ่มไม่ทับแถบ Home/gestures
- การสร้างกิจกรรมยังล็อกวันย้อนหลังตามเดิม

## การทดสอบ
- สมัครองค์กร: เปิด Bottom Sheet เลือกวันย้อนหลังและกดยืนยันได้ ค่าถูกเติมเป็น YYYY-MM-DD
- สร้างกิจกรรม: ไม่สามารถเลือกวันย้อนหลัง (ถ้าใช้ CalendarPicker)
- ตรวจสอบบนอุปกรณ์ที่มี Home Indicator หนา (iOS/Android gestures) ปุ่มยังมองเห็นและกดได้