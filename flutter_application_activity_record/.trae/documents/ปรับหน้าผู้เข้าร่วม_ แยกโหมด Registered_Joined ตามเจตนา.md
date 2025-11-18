## เป้าหมาย
- รายการหน้า Participants: สลับโหมด Registered/Joined เพื่อกรองกิจกรรมตามสถานะเวลา
- หน้า Participants Details:
  - โหมด Registered: แสดงเฉพาะผู้ลงทะเบียน และมีปุ่มสแกน QR เพื่อยืนยันเข้าร่วม
  - โหมด Joined: แสดงเฉพาะผู้ที่เข้าร่วมแล้ว ไม่มีหัวข้อ Registered/Joined และซ่อนปุ่มสแกน QR

## แนวทางแก้
1. ActivitiesParticipantsListScreen
   - เพิ่ม state `_showJoined` และกรองรายการกิจกรรมตามสถานะเวลา (`เริ่มแล้ว/สิ้นสุด` ถือเป็น Joined, อื่นๆ เป็น Registered)
   - ปรับ ChoiceChip ให้สลับ `_showJoined` จริง และสไตล์ selected/ไม่ selected
   - ส่งพารามิเตอร์ไปหน้า Details ว่าเป็นโหมด `isJoinedView`
2. ParticipantsDetailsScreen
   - เพิ่มพารามิเตอร์ `isJoinedView` (default false)
   - ลบหัวข้อ/ชิป `Registered/Joined` ออกจากหน้ารายละเอียด
   - แสดงรายการตามโหมด: `Registered` → `_registered` พร้อม FAB สแกน QR, `Joined` → `_joined` และซ่อน FAB
   - ปรับหัวข้อในส่วนรายชื่อให้ตรงกับโหมด

## การทดสอบ
- ขณะอยู่โหมด Registered ในรายการ: เลือกกิจกรรมที่ยังไม่เริ่ม → เข้า Details เห็นเฉพาะ Registered และมีปุ่มสแกน
- โหมด Joined ในรายการ: เลือกกิจกรรมที่เริ่มแล้ว/จบแล้ว → เข้า Details เห็นเฉพาะ Joined และไม่มีปุ่มสแกน
- สแกน QR ในโหมด Registered: ย้ายรายชื่อจาก Registered → Joined ตามเดิม

ขออนุมัติให้ดำเนินการตามแผนนี้