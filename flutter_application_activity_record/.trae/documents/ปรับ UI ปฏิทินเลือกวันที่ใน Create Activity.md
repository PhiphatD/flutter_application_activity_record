## เป้าหมาย
- ปรับส่วนเลือกวันที่ใน Step 1 ของหน้า Create Activity ให้เป็นปฏิทินแบบอินไลน์ตามตัวอย่างภาพ
- รองรับ 2 โหมด: เลือกช่วงวันที่ (Range) และเลือกหลายวัน (Multiple)

## แนวทาง
- สร้างวิดเจ็ตใหม่ `CalendarPicker` ภายใต้ `lib/screens/organizer_screens/activities/widgets/` เพื่อให้ใช้ซ้ำได้
- คุณสมบัติ:
  - ส่วนหัวเดือน/ปี พร้อมปุ่มเลื่อนเดือนก่อน/ถัดไป
  - แสดงชื่อวันจันทร์–อาทิตย์ และกริดวันที่ของเดือน
  - สไตล์: วันที่ที่เลือกเป็นเหลือง (`chipSelectedYellow`), วันที่นอกเดือนเป็นเทา
  - โหมด Range: แตะครั้งแรก = start, ครั้งที่สอง = end, แตะอีกครั้งรีเซ็ตเริ่มใหม่
  - โหมด Multiple: แตะสลับเลือก/ยกเลิกหลายวันได้
  - คืนค่าไปยังหน้าหลักด้วย callback (`onRangeChanged`, `onMultiChanged`)

## การเชื่อมต่อกับหน้า Create Activity
- ปรับ `activity_create_screen.dart`:
  - คงตัวเลือก Radio เลือกโหมด Range/Multiple
  - แสดง `CalendarPicker` ใต้ตัวเลือกโหมด
  - อัปเดต `_dateRange` หรือ `_multipleDates` จาก callback ของวิดเจ็ต
  - คงตัวเลือกเวลา Start/End ตามเดิม

## สไตล์
- ใช้ `GoogleFonts.poppins`
- สีตามธีม: `organizerBg`, `chipSelectedYellow`

## ทดสอบ
- รัน `flutter analyze` ตรวจ error
- เปิดหน้า Organizer → Create Activity → ทดสอบเลือกวันที่ทั้งสองโหมด ตรวจว่าค่าแมปเป็น sessions ได้ถูกต้อง

กรุณายืนยัน เพื่อให้ผมสร้างวิดเจ็ต `CalendarPicker` และเชื่อมเข้ากับ Step 1 ของหน้า Create Activity