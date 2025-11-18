## ภาพรวม
- เป้าหมาย: เมื่อเข้า Activity Detail จากหน้า Management ของ Organizer ให้ปิดการกดลงทะเบียน (ซ่อน/ปุ่มเป็น disabled) เพื่อให้ผู้จัดกิจกรรมไม่สามารถลงทะเบียนได้
- ขอบเขต: ปรับเฉพาะการแสดงผลใน `ActivityDetailScreen` เมื่อเป็นมุมมองของ Organizer โดยไม่กระทบการใช้งานของพนักงานทั่วไป

## สภาพโค้ดปัจจุบัน
- หน้า Management เรียกไปที่ Activity Detail ที่ `activities_management_screen.dart` g:\BU\Project\SENIER Project\flutter_application_activity_record\flutter_application_activity_record\lib\screens\organizer_screens\activities\activities_management_screen.dart:233-241
- หน้า Activity Detail แสดงปุ่มด้านล่าง ที่เปิดให้ "Register for Activity"/"Cancel Registration" ตามสถานะ `_isRegistered` ใน `activity_detail_screen.dart` g:\BU\Project\SENIER Project\flutter_application_activity_record\flutter_application_activity_record\lib\screens\employee_screens\activities\activity_detail_screen.dart:329-373

## แนวทางแก้
1. เพิ่มพารามิเตอร์ใหม่ใน `ActivityDetailScreen` เช่น `isOrganizerView` (ค่าเริ่มต้น `false`) เพื่อบ่งบอกว่าหน้าถูกเปิดในบริบท Organizer
2. ปรับเงื่อนไขใน `_buildBottomActionButton()` ให้เมื่อ `isOrganizerView == true` แสดงปุ่มแบบ disabled หรือซ่อนปุ่มลงทะเบียน เช่น แสดงปุ่มสีเทา พร้อมข้อความว่า "สำหรับผู้จัดกิจกรรม ไม่สามารถลงทะเบียนได้"
3. ปรับการเรียกหน้า Activity Detail จากหน้า Management ให้ส่ง `isOrganizerView: true` ที่จุดกดรายการ ในไฟล์ `activities_management_screen.dart` ตำแหน่งเรียก `Navigator.push(...)` ตามบรรทัด 233-241
4. รักษาความเข้ากันได้ย้อนหลัง: ส่วนที่เรียก `ActivityDetailScreen` จากหน้าพนักงาน (`employee`) จะไม่ต้องแก้ เพราะพารามิเตอร์ใหม่มีค่า default เป็น `false`

## รายละเอียดการเปลี่ยนแปลง
- แก้ signature ของ `ActivityDetailScreen` ให้รองรับ `final bool isOrganizerView;` พร้อมรับใน constructor แบบ optional และกำหนด default เป็น `false`
- ใน `_buildBottomActionButton()` เพิ่มเงื่อนไขพิเศษบนสุด: ถ้า `widget.isOrganizerView` เป็น `true` ให้แสดงปุ่ม disabled (หรือ `SizedBox.shrink()` ถ้าต้องการซ่อนทั้งหมด) แทนการแสดงปุ่ม Register/Cancel
- ใน `activities_management_screen.dart` เมื่อ `onTap` ของ `_OrganizerActivityCard` เรียก `ActivityDetailScreen(activityId: a.actId.toString(), isOrganizerView: true)`

## ผลกระทบและการทดสอบ
- ผลกระทบต่อผู้ใช้: Organizer จะเห็นว่าปุ่มลงทะเบียนใช้งานไม่ได้ใน Activity Detail เมื่อเข้าโดยผ่านหน้า Management ส่วนพนักงานทั่วไปยังใช้งานได้ปกติ
- การทดสอบ
  - เปิดรายการจากหน้า Management แล้วเข้า Activity Detail ของกิจกรรมใดๆ: ปุ่มลงทะเบียนต้องเป็น disabled/ถูกซ่อน
  - เปิด Activity Detail จากหน้า Employee (`ActivityCard`/`Todo Activity Card`): ปุ่มลงทะเบียนต้องทำงานปกติ
  - ตรวจสอบกรณี Event Finished: ยังคงแสดง "Event Finished" เป็น disabled ตามเดิม

## แผนการปรับแบบข้อความและ UX
- ข้อความปุ่มเมื่อเป็น Organizer: ใช้ "สำหรับผู้จัดกิจกรรม ไม่สามารถลงทะเบียนได้" เพื่อชัดเจนว่าเป็นข้อจำกัดตามบทบาท
- สไตล์: ใช้ปุ่ม `ElevatedButton` สีเทา (`Colors.grey[300]`) และ `onPressed: null` เพื่อสื่อว่าไม่สามารถกดได้

ต้องการให้ดำเนินการตามแผนนี้หรือไม่?