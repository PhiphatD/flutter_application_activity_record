## เป้าหมาย
- ไม่ให้มี UX ปุ่มสแกน QR ในหน้าหลักรายการ Participants
- คงปุ่มสแกน QR เฉพาะในหน้า Participants Details ของกิจกรรม

## แนวทางแก้
1. ลบ `floatingActionButton` ออกจาก `ActivitiesParticipantsListScreen`
2. ไม่เปลี่ยนส่วนอื่นของหน้า (Search, Chips, รายการการ์ด)
3. หน้า Details ยังคงมีปุ่มสแกน QR ตามที่ทำไว้ก่อนหน้า

## การทดสอบ
- เปิดหน้ารายการ Participants: ไม่มีปุ่ม QR ที่มุมล่างขวา
- เข้าหน้า Details: ปุ่ม QR ยังอยู่และใช้งานได้ตามปกติ

ขออนุมัติให้ดำเนินการตามแผนนี้