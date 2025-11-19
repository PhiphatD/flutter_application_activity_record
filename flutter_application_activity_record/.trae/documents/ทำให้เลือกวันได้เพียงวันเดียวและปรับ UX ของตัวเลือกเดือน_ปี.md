## เป้าหมาย

* บังคับให้ผู้ใช้เลือกวันได้ “เพียงวันเดียว” ใน Bottom Sheet ของ Start Date

* ปรับ UX ของตัวเลือก “เดือน/ปี” ให้ง่ายและสวยทันสมัยต่อเนื่องจากเดิม

## แนวทางเทคนิค

* เพิ่มพารามิเตอร์ใหม่ใน `CalendarPicker`: `singleSelection` (default: false)

  * เมื่อ `mode == CalendarMode.multi` และ `singleSelection == true` → เลือกวันแล้วจะเคลียร์วันก่อนหน้าให้เหลือวันล่าสุดเท่านั้น

* ปรับการเรียกใช้ใน `organization_register_screen.dart` ให้ส่ง `singleSelection: true`

* คงการเลือกย้อนหลังด้วย `allowPast: true` สำหรับการสมัคร และคง UX chips เดือน/ปี ที่ทำแล้ว

## รายการแก้ไขไฟล์

1. `lib/screens/organizer_screens/activities/widgets/calendar_picker.dart`

* เพิ่มฟิลด์ `final bool singleSelection;` ในคอนสตรัคเตอร์

* ปรับ `_onTapDay` เมื่ออยู่ในโหมด `multi`:

```dart
if (widget.singleSelection) {
  _multi..clear()..add(d);
} else {
  if (_multi.contains(d)) _multi.remove(d); else _multi.add(d);
}
widget.onMultiChanged?.call(_multi.toList()..sort((a,b)=>a.compareTo(b)));
setState(() {});
```

1. `lib/screens/auth/register/organization_register_screen.dart`

* ใน `_openStartDatePicker()` ส่ง `singleSelection: true` เข้า `CalendarPicker`

## ผลลัพธ์คาดหวัง

* เลือกวันได้เพียงวันเดียวใน Bottom Sheet ของ Start Date

* ตัวเลือกเดือน/ปีใช้งานได้สะดวกและดูทันสมัยตามที่ปรับไว้แล้ว

## การทดสอบ

* เปิด Bottom Sheet → แตะหลายวันจะเหลือไฮไลต์ล่าสุดเพียงวันเดียว

* เปลี่ยนเดือน/ปีจากชิพ → ปฏิทินอัปเดต และยังสามารถเลือกย้อนหลังได้

