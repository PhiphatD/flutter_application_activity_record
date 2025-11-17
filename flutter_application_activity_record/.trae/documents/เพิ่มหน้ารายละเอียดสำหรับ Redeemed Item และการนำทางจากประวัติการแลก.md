## ภาพรวม
- เพิ่มความสามารถให้ผู้ใช้ "กดดูรายละเอียด" ของรางวัลที่แลกไปแล้วในแท็บ Redeemed
- ใช้หน้ารายละเอียดรูปแบบเดียวกับ Reward Detail แต่เป็นโหมด read-only แสดงวันเวลาแลก, หมวดหมู่, คะแนน และภาพ (carousel)

## การเปลี่ยนแปลงข้อมูล
1. ขยายโมเดล `_RedeemedItem` ใน `lib/screens/employee_screens/reward_screen.dart` ให้มีข้อมูลอ้างอิงไปยังรางวัลต้นทาง และ snapshot ที่จำเป็น:
- เพิ่มฟิลด์: `sourceRewardId` (id ของ `_RewardItem`), `description`, `imageUrls`
- เวลาเรียก `_redeemReward(item)` ให้บันทึกค่าจาก `item` ลงใน `_RedeemedItem`

2. รองรับกรณีข้อมูลเก่า (ยังไม่มี `sourceRewardId` หรือ `imageUrls`):
- เวลาเปิดรายละเอียด ให้ค้นหา `_RewardItem` ที่ตรงกับ `name` หรือพยายามแยก id จาก `rd_${item.id}_...` เพื่อดึงภาพ/รายละเอียดมาเติม

## UI และการนำทาง
1. สร้างหน้าใหม่ `RedeemedDetailScreen` (ไฟล์ใหม่ใน `lib/screens/employee_screens/redeemed_detail_screen.dart`):
- รับพารามิเตอร์: `name`, `pointsCost`, `category`, `redeemedAt`, `description`, `imageUrls`
- แสดงภาพแบบ carousel ด้วย `PageView + SmoothPageIndicator`
- แสดงกล่องข้อมูล (คะแนนที่ใช้, วันที่แลก, หมวดหมู่) และรายละเอียด
- ปุ่มล่างเป็นสถานะ `Redeemed` ที่ disabled (ไม่มีการแลกซ้ำ)

2. เพิ่มการกดเข้าไปดูรายละเอียดจากรายการ Redeemed:
- ใน `_buildRedeemedList()` ให้ห่อ `_RedeemedItemCard` ด้วย `InkWell` หรือส่ง `onTap` เข้าไป
- เมื่อกด: นำข้อมูลไป `Navigator.push` ไป `RedeemedDetailScreen`
- ถ้าบางรายการไม่มีรูป/รายละเอียด ให้ส่งค่าว่างและจัดการ UI ไม่ให้พัง

## จุดแก้ไขหลัก
- `reward_screen.dart`:
  - ขยายคลาส `_RedeemedItem`
  - ปรับ `_redeemReward()` ให้ใส่ `sourceRewardId`, `description`, `imageUrls`
  - ปรับ `_buildRedeemedList()`/`_RedeemedItemCard` ให้รองรับ `onTap` และนำทางไปหน้าใหม่
- เพิ่มไฟล์ `redeemed_detail_screen.dart` พร้อม UI (carousel, description, redeemed badge)

## ทดสอบ
- แลกรางวัล → ไป Redeemed → กดรายการ → เห็นรายละเอียดครบ (รูป, คะแนน, หมวดหมู่, วันที่แลก, description)
- กรณีไม่มีรูป/รายละเอียด: หน้าแสดงเนื้อหาอย่างปลอดภัย
- กลับย้อนหน้าทำงานปกติ

## หมายเหตุ
- โค้ดจะไม่กระทบ flow การแลกเดิม
- ถ้าต้องการรวมรายละเอียด redeemed เข้ากับหน้าปัจจุบัน `RewardDetailScreen` สามารถทำเป็นพารามิเตอร์ `isRedeemed: true` เพื่อ reuse UI ได้เช่นกัน แต่แผนนี้แยกไฟล์เพื่อความชัดเจน