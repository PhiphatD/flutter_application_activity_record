## เป้าหมาย
- ให้หน้ารายละเอียดรางวัลเรียกใช้คอมโพเนนต์ยืนยันการแลก `RewardConfirmationBottomSheet` ที่มีอยู่ใน `lib/widgets`

## แนวทางแก้
1. เพิ่ม import `package:flutter_application_activity_record/widgets/reward_confirmation_bottom_sheet.dart` ใน `reward_detail_screen.dart`
2. แทนที่การเรียก `showModalBottomSheet` ในเมธอด `_handleRedeem()` ด้วย `RewardConfirmationBottomSheet.show(...)`
3. ในพารามิเตอร์ `onConfirm`, ปิด bottom sheet และปิดหน้า detail แล้วเรียก `widget.onRedeem()` ตามพฤติกรรมเดิม

## การทดสอบ
- เปิด Reward Detail → กด Redeem → เห็น Bottom Sheet ยืนยันจากคอมโพเนนต์ใหม่
- กด Confirm → ปิด Bottom Sheet และ Detail, กลับไปหน้า Reward พร้อมอัปเดตเป็น Redeemed

ขออนุมัติให้ดำเนินการตามแผนนี้