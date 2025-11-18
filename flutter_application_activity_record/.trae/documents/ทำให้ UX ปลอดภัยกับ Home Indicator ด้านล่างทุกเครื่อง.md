## เป้าหมาย
- ป้องกัน UI ทับซ้อนกับ Home Indicator/Navigation bar ด้านล่างบนโทรศัพท์ทุกเครื่อง
- ครอบคลุมหน้าที่มีปุ่มลอย (FAB) และส่วนปุ่มการทำงานด้านล่าง (bottom action bar)

## แนวทางแก้
1. ห่อส่วน `bottomNavigationBar` ด้วย `SafeArea(bottom: true)` เพื่อกันพื้นที่ด้านล่างแบบไดนามิก
2. ห่อ `FloatingActionButton` ทุกหน้าที่เกี่ยวข้องด้วย `SafeArea(bottom: true)` และเพิ่มระยะห่างเล็กน้อย
3. เพิ่ม `bottom` padding ให้ `ListView` ด้วย `MediaQuery.of(context).padding.bottom` เพื่อไม่ให้รายการท้ายจอถูกทับ

## ไฟล์ที่จะปรับ
- `employee_screens/activities/activity_detail_screen.dart`: ห่อ `bottomNavigationBar` ด้วย `SafeArea`
- `organizer_screens/activities/activities_management_screen.dart`: ห่อ `floatingActionButton` ด้วย `SafeArea`
- `organizer_screens/participants/activities_participants_list_screen.dart`: ห่อ `floatingActionButton` ด้วย `SafeArea`, เพิ่ม bottom padding ให้ `ListView`
- `organizer_screens/participants/participants_details_screen.dart`: ห่อ `floatingActionButton` ด้วย `SafeArea`, เพิ่ม bottom padding ให้ `ListView`

## การทดสอบ
- เปิดแต่ละหน้าในอุปกรณ์ที่มี Home Indicator ด้านล่าง: ปุ่มและเนื้อหาไม่ถูกทับ, เลื่อนถึงท้ายรายการยังเห็นชัด
- ทดสอบในอุปกรณ์ไม่มี Home Indicator: ระยะห่างยังดูสมดุล

ขออนุมัติให้ดำเนินการตามแผนนี้