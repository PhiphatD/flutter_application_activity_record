## เป้าหมาย
- สร้างหน้า Create Activity เป็นขั้นตอน 3 หน้าที่สอดคล้องกับโมเดล ACTIVITY และ ACTIVITY_SESSION ตามสเปค
- รองรับการเลือกวันที่แบบช่วง (Range) และหลายวัน (Multiple) พร้อม Mapping เป็น Session(s)
- UI ตามธีม Organizer (พื้นหลังเหลืองอ่อน), ปุ่ม Next/Previous ชัดเจน

## โครงสร้างและไฟล์
- ปรับปรุงไฟล์เดิม: `lib/screens/organizer_screens/activities/activity_create_screen.dart`
- คงชื่อคลาส `CreateActivityScreen` แต่ภายในเป็น Wizard 3 ขั้นตอน ด้วย `PageController` และปุ่ม Next/Previous
- ใช้สีจากธีม: `organizerBg` (import จาก `theme/app_colors.dart`)

## โมเดลในหน้า
- สร้างคลาสภายในไฟล์: `ActivityFormData` ประกอบด้วยฟิลด์ทั้งหมดที่ระบุ
- สร้าง `List<DateTime> selectedDates` หรือ `DateTimeRange? selectedRange`
- เมธอด `buildSessions()` คืนค่า `List<ActivitySessionDraft>` จากโหมดวันที่ (Range หรือ Multiple)

## Step-by-step UI
- Step 1 (Basic Info)
  - Inputs: Activity Name, Type (Dropdown: Training/Seminar/Workshop), Descriptions, Location, Points, Date Mode (Radio: Range หรือ Multiple), ปุ่มเลือกวันที่ (เปิด `showDateRangePicker` หรือ `showDatePicker` ซ้ำ), Time Start/End (`showTimePicker`)
  - แสดงสรุปวันที่/เวลาใต้ปุ่มเลือก
- Step 2 (Host & Participants)
  - Inputs: Guest Speaker, Event Host, Organizer (auto-fill จาก Current User – mock ด้วย string ชั่วคราว), Organizer Contact Info, Max Participants, Department (Dropdown – mock รายการ), Participation Fee (Double)
- Step 3 (Details & Conditions)
  - Inputs: Travel Arrangement, Food Provided, More details (multi-line), Participation Condition (String), Activity Status (Radio: 0 Normal, 1 Compulsory)
  - ปุ่ม Create (แทน Next) ส่งข้อมูล

## การทำงานและ Mapping
- เมื่อกด Create:
  - แปลงวันที่จาก Step 1 เป็นรายการ Session: `SESSION_DATE`, `START_TIME`, `END_TIME`
  - สร้างอ็อบเจ็กต์รวมที่พร้อมส่งให้ API ในอนาคต (ตอนนี้จะ `Navigator.pop` พร้อมส่งผลกลับ)

## การเชื่อมต่อ
- FAB ใน `activities_management_screen.dart` เรียก `CreateActivityScreen` อยู่แล้ว ไม่ต้องแก้
- เมื่อสร้างเสร็จ จะ `Navigator.pop(context, result)` เพื่อให้หน้ารายการสามารถรับผล (ต่อไปหากต้องการเพิ่มลง list)

## สไตล์
- พื้นหลัง: `organizerBg`
- ฟอนต์: `GoogleFonts.poppins`
- ปุ่ม Choice/Radio ตามดีไซน์ และปุ่ม Next/Previous ที่มุมขวาล่าง/ซ้ายล่าง

## การทดสอบ
- รัน `flutter analyze` ตรวจ syntax/import
- เปิดหน้า Organizer → กด FAB → กรอกข้อมูล Step 1–3 → กด Create ดูว่าข้อมูลวันที่/time แปลงเป็น sessions ได้ถูกต้อง

กรุณายืนยัน เพื่อให้ผมลงมือปรับโค้ดในไฟล์ `activity_create_screen.dart` ให้เป็น Wizard 3 ขั้นตอน พร้อม Form และ Mapping ตามที่กำหนด