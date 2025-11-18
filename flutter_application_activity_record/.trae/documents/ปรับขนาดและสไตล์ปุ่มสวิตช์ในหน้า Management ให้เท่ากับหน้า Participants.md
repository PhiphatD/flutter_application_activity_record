## เป้าหมาย
- ทำให้ปุ่มสวิตช์ My Activities / Other Organizers ในหน้า Management มีขนาดและสไตล์เหมือนปุ่ม Registered / Joined ในหน้า Participants

## วิธีปรับ
- ปรับเมธอด `_buildViewSwitcher()` ใน `lib/screens/organizer_screens/activities/activities_management_screen.dart`
- ใช้รูปแบบเดียวกับ Participants:
  - `ChoiceChip` มี `labelPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 8)`
  - `backgroundColor: Colors.white`, `selectedColor: chipSelectedYellow`
  - `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0), side: BorderSide(color: selected ? chipSelectedYellow : Colors.grey.shade400))`
  - `showCheckmark: false`
  - `labelStyle`: เมื่อเลือกเป็นตัวหนา สีดำ; ไม่เลือกเป็นสีดำอ่อน ตัวปกติ
- สร้าง helper `_buildPill(String label, bool selected, VoidCallback onSelected)` เพื่อหลีกเลี่ยงโค้ดซ้ำสองปุ่ม

## การทดสอบ
- `flutter analyze` ตรวจ error
- เปิดหน้า Organizer → Management ตรวจสอบว่าปุ่มสวิตช์มีขนาด/สไตล์เหมือน Participants และโทนสีเหลือง/เทาตามดีไซน์

กรุณายืนยัน เพื่อให้ผมปรับโค้ดตามรายการนี้