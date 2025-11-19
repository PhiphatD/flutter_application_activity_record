## เป้าหมาย
- ปีที่เลือกใน Year picker ต้องสะท้อนที่หัวปฏิทินทันที
- สีของปฏิทินและปุ่มใช้จากธีมของแอป
- ลดช่องว่างด้านล่างระหว่างปฏิทินกับปุ่มยืนยัน

## สาเหตุที่เป็นไปได้
- ค่าที่ใช้แสดงหัวปฏิทิน (currentDate) ถูกตั้งคงที่เป็น `DateTime.now()` ทำให้หัวปฏิทินไม่อัปเดตตามปีที่เลือก
- Layout ใช้ `Container(height: ... 0.7)` + `Expanded` ทำให้เกิดพื้นที่ว่างส่วนเกินเมื่ออยู่โหมด Year grid
- สีระบุแบบคงที่ (`0xFF222222`) ไม่ดึงจาก `Theme.of(context)`

## การแก้ไข (ไฟล์: `lib/screens/auth/register/organization_register_screen.dart`)
- จุดแก้ไขบริเวณฟังก์ชัน `_openStartDatePicker()`

### 1) ให้หัวปฏิทินอัปเดตตามปีที่เลือก
- เปลี่ยนค่าใน `CalendarDatePicker2Config` จาก `currentDate: DateTime.now()` เป็น `currentDate: (tempDates.first ?? initialDate)` เพื่อให้หัวเดือน-ปีของตัวคอนโทรลสะท้อนตามค่าที่เลือก (อัปเดตทุกครั้งที่ `onValueChanged` เรียก `setStateBottomSheet`).
- อ้างอิงการตั้งค่า config ของแพ็กเกจ `calendar_date_picker2` รองรับการปรับ style และ behavior ผ่าน config [pub.dev/calendar_date_picker2].

ตำแหน่งอัปเดต:
- `organization_register_screen.dart:551–590` (บล็อก `CalendarDatePicker2(config: ...)`)

### 2) ปรับสีให้เข้าธีมของแอป
- ใช้ `Theme.of(context).colorScheme.primary` แทนสีคงที่ใน
  - `selectedDayHighlightColor`
  - `selectedDayTextStyle` → ใช้ `colorScheme.onPrimary`
  - `yearTextStyle`, `dayTextStyle`, `weekdayLabelTextStyle` → ใช้ `colorScheme.onSurface`/`textTheme`
- ปุ่มยืนยันใช้ `styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary)`

ตำแหน่งอัปเดตสี:
- `organization_register_screen.dart:557–585` และปุ่ม: `600–627`

### 3) ลดช่องว่างด้านล่าง
- ลบ `height: MediaQuery.of(context).size.height * 0.7` ออกจาก `Container` เพื่อให้ bottom sheet สูงตามเนื้อหา
- เปลี่ยน `Expanded(child: CalendarDatePicker2(...))` เป็นใส่ตรงๆ หรือใช้ `Flexible(fit: FlexFit.loose)` เพื่อไม่บังคับให้ยืดเต็มความสูง
- ตั้ง `Column(mainAxisSize: MainAxisSize.min)` ให้เคารพความสูงเนื้อหา
- ลด `padding` ของส่วนปุ่มจาก `EdgeInsets.fromLTRB(20, 10, 20, 30)` เป็นเช่น `EdgeInsets.fromLTRB(20, 8, 20, 16)`

ตำแหน่งเลย์เอาต์:
- `organization_register_screen.dart:520` (Container height), `551–599` (เอา `Expanded` ออก), `526–529` (เพิ่ม `mainAxisSize: MainAxisSize.min`), `601–627` (ปรับ padding)

## ผลลัพธ์ที่คาดหวัง
- เมื่อเลือกปี (เช่น 2025) หัวปฏิทินแสดงปี 2025 ทันที
- สีของวงปี/วันและปุ่มยืนยันเข้ากับธีมแอป
- ช่องว่างใต้ปฏิทินลดลง ให้ความรู้สึกกระชับ

## หมายเหตุ
- ใช้เวอร์ชันแพ็กเกจ `calendar_date_picker2: ^2.0.1` ซึ่งรองรับการตั้งค่า style ผ่าน `CalendarDatePicker2Config` และตัวเลือกเสริม (เช่น `centerAlignModePicker`, `yearBuilder`) ตามเอกสาร [1].

[1] https://pub.dev/packages/calendar_date_picker2