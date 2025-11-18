## เป้าหมาย
- ย้ายปุ่ม Edit และ Delete จากด้านล่างไปไว้ด้านขวามือของข้อมูล (ถัดจาก Location/Organizer) และเรียงแนวตั้งตามสเปค
- คงส่วน Type และ Participants ไว้ด้านล่างเหมือนเดิม

## จุดแก้ไข
- ไฟล์: `lib/screens/organizer_screens/activities/activities_management_screen.dart`
- ภายในวิดเจ็ต `_OrganizerActivityCard.build`
- แทนที่บล็อกหลัง `Divider` ด้วยโค้ด Row+Column ตามที่คุณให้มา
- ลบชุดปุ่มเดิมที่อยู่ท้ายคอลัมน์ (`if (showActions) ... Row(TextButton.icon ...)`)

## รายละเอียดโค้ดที่จะใส่
- หลัง `const Divider(...), const SizedBox(height: 8.0),` ใส่ `Row` ที่มี:
  - ซ้าย: `Expanded(Column(...))` แสดง `_buildInfoRow` สำหรับ `location`, `organizer`, `points`
  - ขวา: เมื่อ `showActions` เป็นจริง ให้แสดง `Column` ที่มีปุ่ม `InkWell` สองปุ่ม (Edit บน, Delete ล่าง)
- ตามด้วย `const SizedBox(height: 12.0)`
- ตามด้วย `Row` ของ Type/Participants เดิม

## การทดสอบ
- รัน `flutter analyze` เพื่อตรวจว่าไม่มี error ทางไวยากรณ์
- เปิดหน้า Organizer → Activities Management แล้วตรวจสอบการ์ด:
  - เห็นปุ่ม Edit/Delete ชิดขวา เรียงแนวตั้ง
  - กด Edit นำทางไปหน้าแก้ไข, กด Delete แสดง dialog และลบรายการได้

## หมายเหตุด้านความเสถียร
- ใช้ `InkWell` ตามสเปคและรักษา `GoogleFonts` เดิม
- ไม่เปลี่ยนชื่อเมธอดช่วยอย่าง `_buildInfoRow` และ `_buildTypePill`

กรุณายืนยัน เพื่อให้ผมปรับโค้ดตามที่ระบุและทดสอบให้เรียบร้อย