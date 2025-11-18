## เป้าหมาย
- ปรับหน้ารายละเอียดรางวัลและหน้ารายละเอียดที่แลกรางวัลแล้ว รวมถึงคอมโพเนนต์ Bottom Sheet ให้ไม่ถูกทับด้วย Home Indicator/แถบนำทางด้านล่าง

## ปรับไฟล์
1. `employee_screens/rewards/reward_detail_screen.dart`
- ห่อ `bottomNavigationBar` ด้วย `SafeArea(bottom: true)`
- เมื่อเปิด Bottom Sheet ยืนยันการแลก ให้ห่อเนื้อหาด้วย `SafeArea(bottom: true)`

2. `employee_screens/rewards/redeemed_detail_screen.dart`
- ห่อ `bottomNavigationBar` ด้วย `SafeArea(bottom: true)`

3. `widgets/reward_confirmation_bottom_sheet.dart`
- ห่อเนื้อหา Container ด้วย `SafeArea(bottom: true)` และเพิ่ม `bottom` padding ด้วย `MediaQuery.of(context).padding.bottom`

## การทดสอบ
- เปิดหน้ารายละเอียดรางวัล/แลกรางวัลในอุปกรณ์ที่มี Home Indicator: ปุ่มล่างไม่ชนอินดิเคเตอร์, Bottom Sheet ไม่ถูกทับด้านล่าง
- อุปกรณ์ไม่มี Home Indicator: ระยะห่างยังดูสมดุล

ขออนุมัติให้ดำเนินการตามแผนนี้