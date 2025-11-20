## วิเคราะห์สาเหตุ
- จุดที่ผิดพลาดอยู่ในหัววันที่ของรายการกิจกรรม (`_buildList`) ที่ใช้
  - `Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [...])`
- หนึ่งในลูกของ Row คือ `Container` สำหรับป้าย "TODAY" (บรรทัด ~236–254)
- เมื่อใช้ `CrossAxisAlignment.baseline` Flutter จะ assert ให้ **ทุกลูกของ Row ต้องมี baseline** (เช่น `Text`, หรือห่อด้วย `Baseline`)
- `Container` ไม่ให้ baseline จึงเกิด runtime assertion เช่น "No baseline found for... Row/Column with baseline"

## แผนการแก้ไข
- เปลี่ยนการจัดแนวใน Row จาก `CrossAxisAlignment.baseline` เป็น `CrossAxisAlignment.center`
- ลบ `textBaseline` ออก เพราะจะไม่ถูกใช้เมื่อไม่ใช่ baseline alignment
- โครงสร้าง UI จะยังเรียงแนวกลาง ดูเนียนตา และไม่มี assert

## จุดแก้ไขในไฟล์
- แก้ที่ `lib/screens/organizer_screens/activities/activities_management_screen.dart`
- บล็อก Row หัววันที่: ประมาณบรรทัด 231–271

## ผลลัพธ์
- หน้า Activity Management จะไม่ crash/throw assert อีก
- ป้าย "TODAY" และข้อความวันที่ยังจัดแนวกลางสวยงาม