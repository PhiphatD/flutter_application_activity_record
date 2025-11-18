## เป้าหมาย
- ปรับสวิตช์ระหว่าง “My Activities” และ “Other Organizers” ในหน้า Organizer ให้เป็นปุ่มพิลแบบ ChoiceChip คล้ายสไตล์ที่ใช้ในฝั่ง Employee
- สีและรูปร่างตามภาพตัวอย่าง: พิลเหลือง (เลือกอยู่) และพิลเทา (ไม่ได้เลือก)

## วิธีปรับ
- ไฟล์: `lib/screens/organizer_screens/activities/activities_management_screen.dart`
- แทนที่ `TabBar + TabBarView` ด้วย `Row` ของ `ChoiceChip` สองตัว และแสดงรายการด้วย `_buildList(selected == My)`
- เพิ่มสเตตภายใน `_ActivityManagementScreenState`: `_selectedSegment` (0=My, 1=Other)
- สร้างเมธอด `_buildViewSwitcher()` คืนค่า Row ของ ChoiceChip สองปุ่ม พร้อมสไตล์ label สีดำบนพื้นเหลืองเมื่อเลือก และพื้นเทาพร้อมตัวอักษรสีดำเมื่อไม่เลือก
- ปรับส่วน build: ใส่ `_buildViewSwitcher()` แทน Container(TabBar) และเปลี่ยน Expanded ให้แสดง `_buildList(_selectedSegment == 0)`

## การทดสอบ
- รัน `flutter analyze` ตรวจ error
- เปิดหน้า Organizer Management ตรวจสอบการสลับระหว่าง My/Other ด้วย ChoiceChip ว่าทำงานและสไตล์ถูกต้อง

กรุณายืนยัน เพื่อให้ผมลงมือปรับโค้ดตามแผนนี้