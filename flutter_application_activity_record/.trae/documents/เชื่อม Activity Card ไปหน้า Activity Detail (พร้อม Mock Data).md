## เป้าหมาย
- เมื่อกดการ์ดใน `activity_card.dart` บนหน้า Feed ให้ไปหน้า `ActivityDetailScreen` แบบเดียวกับที่ทำใน `todo_activity_card.dart` และแสดงรายละเอียดจาก Mock DB

## สิ่งที่จะเปลี่ยนแปลง
- ปรับ `ActivityCard` (ไฟล์ `lib/screens/employee_screens/activity_card.dart`) ให้รับ `id` และนำทางไปยัง `ActivityDetailScreen(activityId: id)` เมื่อกดการ์ด
- ปรับโมเดลในหน้า Feed (`lib/screens/employee_screens/activity_feed_screen.dart`) ให้มี `id` ในคลาส `_Activity` และใส่ `id` ให้ทุกกิจกรรม จากนั้นส่งต่อ `id` เข้าไปในการ์ด
- เพิ่มรายการ Mock ใน `_mockDetailDatabase` ของไฟล์ `lib/screens/employee_screens/activity_detail_screen.dart` ให้รองรับกิจกรรมจากหน้า Feed ที่ยังไม่มีใน DB เพื่อให้ค้นด้วย `id` แล้วเจอรายละเอียดที่ตรงกับการ์ด

## รายละเอียดการแก้ไขไฟล์
### 1) activity_card.dart
- เพิ่มฟิลด์ `final String id;` และ `required this.id` ใน constructor ของ `ActivityCard`
- Import `activity_detail_screen.dart`
- เปลี่ยน `onTap` ใน InkWell จากการ `print` เป็น
  - `Navigator.push(context, MaterialPageRoute(builder: (context) => ActivityDetailScreen(activityId: widget.id)));`
- อ้างอิงตำแหน่งโค้ด:
  - จุดกดการ์ดปัจจุบันอยู่ที่ `lib/screens/employee_screens/activity_card.dart:105-107` (ตอนนี้พิมพ์ `print`)
  - ดูตัวอย่างการนำทางจาก `todo_activity_card.dart:46-51`

### 2) activity_feed_screen.dart
- เพิ่ม `final String id;` ในคลาส `_Activity` และใส่ `required this.id` ใน constructor
- กำหนด `id` ให้กับแต่ละกิจกรรมใน `_mockActivities` (เช่น `"10"`, `"11"`, `"12"`, และใช้ `"4"` สำหรับ "ฝึกอบรม กลยุทธ์การสร้างแบรนด์ 2" ซึ่งมีใน DB อยู่แล้ว)
- ตอนสร้างการ์ดให้ส่ง `id: activity.id` เข้าไปด้วย
- อ้างอิงตำแหน่งโค้ด:
  - โมเดล `_Activity` อยู่ที่ `lib/screens/employee_screens/activity_feed_screen.dart:9-30`
  - สร้างการ์ดอยู่ที่ `lib/screens/employee_screens/activity_feed_screen.dart:378-387` (เพิ่ม `id` ตรงนี้)

### 3) activity_detail_screen.dart
- เพิ่ม Mock รายการใหม่ใน `_mockDetailDatabase` ให้ตรงกับกิจกรรมในหน้า Feed ที่ยังไม่มีใน DB ณ ตอนนี้:
  - `"10"`: ฝึกอบรม กลยุทธ์การสร้างแบรนด์ (type: Training, organizer: Thanuay, points: 200, status: Upcoming)
  - `"11"`: งานสัมนาเทคโนโลยีรอบตัวเรา (type: Seminar, organizer: Thanuay, points: 300, status: Upcoming)
  - `"12"`: Workshop Microsoft365 (type: Workshop, organizer: Thanuay, points: 500, status: Upcoming)
  - ใช้รายการเดิม `"4"` สำหรับ "ฝึกอบรม กลยุทธ์การสร้างแบรนด์ 2"
- เติมข้อมูล fields ที่จำเป็นให้ครบ (`guestSpeaker`, `eventHost`, `organizerContact`, `department`, `participationFee`, `description`, `isRegistered`) เพื่อให้หน้า Detail แสดงข้อมูลครบถ้วน
- อ้างอิงตำแหน่งโค้ด DB: `lib/screens/employee_screens/activity_detail_screen.dart:52-141`

## เหตุผลด้านโครงสร้าง
- คงรูปแบบการทำงานแบบเดียวกับหน้าตาราง To-do: ใช้ `id` เป็น key เพื่อค้นรายละเอียดจาก DB จำลอง และลดการ coupling ระหว่างการ์ดกับหน้า Detail
- แยก `ActivityCard` สองเวอร์ชันไว้ในไฟล์คนละชุดตามการใช้งานจริง (Feed vs. To-do) เพื่อหลีกเลี่ยงการชนกันของ API

## การทดสอบและตรวจสอบ
- เปิดหน้า Feed แล้วกดการ์ดแต่ละใบ:
  - ควรนำทางไปหน้า `ActivityDetailScreen` พร้อมแสดงรายละเอียดถูกต้องตาม `id`
  - รายการที่มีสถานะ `Upcoming` จะแสดงปุ่ม "Register for Activity" ส่วนที่เป็นกิจกรรมจบไปแล้วจะแสดง "Event Finished"
- ตรวจสอบว่า Heart (Favorite) บนการ์ดยังทำงานและไม่รบกวนการนำทาง

## ผลกระทบอื่นๆ
- โค้ดสไตล์และฟอนต์จะยังคงเหมือนเดิม (ใช้ `GoogleFonts.kanit` ตามบริบท)
- ไม่มีการเปลี่ยนแปลง enum หรือสัญญาของหน้า Detail; ยังคง import `ActivityStatus` จาก `todo_activity_card.dart` ตามเดิม

หากตกลงตามแผนนี้ จะดำเนินการแก้ไขทั้ง 3 ไฟล์ให้ครบ และเพิ่ม Mock ที่จำเป็นให้พร้อมทดสอบการนำทางจากหน้า Feed.