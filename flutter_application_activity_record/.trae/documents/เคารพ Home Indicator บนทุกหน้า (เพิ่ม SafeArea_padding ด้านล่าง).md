## เป้าหมาย
- ป้องกันเนื้อหาถูกทับด้วย Home Indicator/แถบนำทางด้านล่างบนทุกอุปกรณ์
- ครอบคลุมทั้งรายการเลื่อนและส่วนปุ่มล่าง

## สิ่งที่มีแล้ว
- หน้าสำคัญบางหน้าเคารพ SafeArea แล้ว: Activity Detail, Organizer Management FAB, Participants List/Details

## สิ่งที่จะปรับเพิ่ม
1. Employee Activity Feed (`employee_screens/activities/activity_feed_screen.dart`)
- ปรับ `ListView.builder` ให้เพิ่ม `bottom: 16.0 + MediaQuery.of(context).padding.bottom`
2. Employee To-do (`employee_screens/activities/todo_screen.dart`)
- ปรับ `ListView.builder` ให้เพิ่ม `bottom: 16.0 + MediaQuery.of(context).padding.bottom`
3. Employee Reward (`employee_screens/rewards/reward_screen.dart`)
- ปรับ `GridView.builder` และ `ListView.builder` ให้ใช้ `bottom: 20.0 + MediaQuery.of(context).padding.bottom`

## หลักการ
- ใช้ SafeArea สำหรับส่วนที่เป็นปุ่มด้านล่าง (ทำแล้วในบางหน้า)
- เพิ่ม bottom padding สำหรับรายการเลื่อนให้คำนึงถึง `MediaQuery.of(context).padding.bottom`

## การทดสอบ
- เปิดแต่ละหน้าในอุปกรณ์ที่มี Home Indicator: เนื้อหาเลื่อนถึงท้ายสุดไม่ถูกทับ, ปุ่มล่างไม่กดชนอินดิเคเตอร์
- อุปกรณ์ไม่มี Home Indicator: ระยะห่างดูสมดุล

ขออนุมัติให้ดำเนินการปรับตามแผนนี้