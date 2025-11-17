## เป้าหมาย
- ปรับปรุงหน้า `Reward` ให้เข้ากับธีมแอป (สี, ฟอนต์, ระยะห่าง, สไตล์การ์ด) และโครงสร้างคล้ายหน้า `To‑do`
- รองรับ 2 มุมมอง: "Reward items" และ "Redeemed items"
- กล่องรายการมีข้อมูลตาม Figma: ชื่อรางวัล, แต้มที่ใช้, ผู้ให้/หมวดหมู่, จำนวนคงเหลือ, วันหมดอายุ, ปุ่ม Redeem/สถานะ Redeemed

## UI หลักให้สอดคล้องกับธีม
- App Bar แบบเดียวกับ Feed/To‑do: แถวบนมีรูปโปรไฟล์ซ้าย, ชื่อหน้า "Reward" ตรงกลาง, ไอคอนแจ้งเตือนขวา; พื้นหลังสีขาว, ฟอนต์ `GoogleFonts.poppins`
- Search Bar และ Filter Segment: เพิ่มแถบค้นหาและตัวสลับมุมมองระหว่าง `Reward items` กับ `Redeemed items` ด้วย ChoiceChip/Segmented Control (ไม่ซ้อน element interactive กัน)
- Header คะแนน: แสดง "Your Points" ด้วยการ์ดพื้นหลังโทน `E2F3FF` โปร่งใส 30% และข้อความใช้สี `#4A80FF`
- การ์ดรายการ: ใช้ BoxDecoration ตามสไตล์การ์ดในแอป (ขาว, เงา, ขอบโค้ง 20, เส้นขอบโปร่ง 20%) และฟอนต์ `GoogleFonts.kanit` สำหรับเนื้อหา

## โครงสร้างข้อมูล (Mock)
- สร้างโมเดล `_RewardItem` สำหรับของรางวัล: `id`, `name`, `pointsCost`, `vendorOrCategory`, `stock`, `expiryDate`, `imageUrl?`, `description`
- สร้างโมเดล `_RedeemedItem`: `id`, `name`, `pointsCost`, `redeemedAt`, `vendorOrCategory`
- สร้าง List จำลอง: `_availableRewards`, `_redeemedRewards` และตัวแปรคะแนนผู้ใช้ เช่น `_userPoints = 1250`

## การทำงาน
- สลับมุมมองด้วย ChoiceChip: `Reward items` และ `Redeemed items`
- ใน `Reward items`: ปุ่ม `Redeem` เปิดใช้งานเมื่อ `stock > 0` และ `userPoints >= pointsCost`; เมื่อ Redeem จะลด `stock`, หักคะแนน, และย้ายไป `_redeemedRewards`
- ใน `Redeemed items`: ปุ่มเป็นสถานะ `Redeemed` (ปิดใช้งาน) พร้อมวันที่แลก
- หลีกเลี่ยงการซ้อน Interactive elements: ปุ่ม `Redeem` อยู่ในการ์ดที่ไม่หุ้มด้วย InkWell; ถ้ามีการกดเพื่อดูรายละเอียด แยก Gesture เฉพาะส่วนเนื้อหาที่ไม่รวมปุ่ม

## รายละเอียดการปรับโค้ด
- `lib/screens/employee_screens/reward_screen.dart`
  - เปลี่ยนจาก Stateless เป็น Stateful เพื่อจัดการคะแนน/สถานะ/มุมมอง
  - เพิ่ม Custom App Bar แบบเดียวกับไฟล์ Feed/To‑do
  - เพิ่ม Search Bar และ ChoiceChip สำหรับสลับ `Reward items`/`Redeemed items`
  - เพิ่ม Header คะแนนด้วยการ์ดพื้นหลัง `Color(0x4DE2F3FF)` และข้อความสีน้ำเงินหลัก `#4A80FF`
  - สร้าง Widget การ์ด: `_RewardItemCard` และ `_RedeemedItemCard` (เป็นเมธอดภายในไฟล์เดียว) ตามสไตล์การ์ดที่ใช้อยู่ในโปรเจกต์

## เกณฑ์ตรวจรับ
- หน้า Reward มี App Bar/ค้นหา/ตัวสลับมุมมอง/การ์ดรายการครบ
- สีและฟอนต์สอดคล้องกับหน้าที่มีอยู่ (Poppins สำหรับหัวข้อ, Kanit สำหรับเนื้อหา, สีหลัก #4A80FF)
- ปุ่ม Redeem ทำงานถูกต้อง, เงื่อนไขเปิด/ปิดปุ่มถูกต้อง, คะแนนและรายการ Redeemed อัปเดตตามการแลก
- ไม่มีการซ้อน Interactive elements กัน

## ขั้นตอนดำเนินการ
1) รีแฟกเตอร์ `reward_screen.dart` เป็น Stateful และเพิ่ม state ที่จำเป็น
2) เติม Custom App Bar, Search Bar, ChoiceChip สลับมุมมอง
3) เพิ่ม Header คะแนน
4) สร้าง Mock data + การ์ดรายการ + logic Redeem
5) ตรวจทดสอบการทำงานและทวนสไตล์ให้ตรงกับธีมแอป