## เป้าหมาย
- เพิ่มช่อง "Start Date" ในฟอร์มสมัครองค์กร และบังคับกรอก
- ใช้ CalendarPicker (จาก organizer activities) เปิดเป็น Bottom Sheet เมื่อแตะช่อง
- จำกัดให้เลือกได้วันเดียวและแปลงเป็น YYYY-MM-DD ส่งไป API

## การเปลี่ยนแปลงหลัก
1) เพิ่ม Controller และ Dispose
- เพิ่ม `final _adminStartDateController = TextEditingController();`
- ใน `dispose()` เรียก `_adminStartDateController.dispose();`

2) เพิ่มฟังก์ชันเปิดตัวเลือกวันที่
- `void _openStartDatePicker()` → `showModalBottomSheet(isScrollControlled: true)`
- ใส่ `FractionallySizedBox(heightFactor: 0.6)`
- วาง `CalendarPicker(mode: CalendarMode.multi, initialMulti: [selected])`
- ใน `onMultiChanged` เก็บวันล่าสุดที่เลือกไว้ในตัวแปรชั่วคราว และแสดงปุ่ม “ใช้วันที่นี้” เพื่อยืนยัน
- เมื่อยืนยัน แปลงเป็น `YYYY-MM-DD` ใส่ `_adminStartDateController.text` แล้วปิด Bottom Sheet

3) เพิ่มฟิลด์ Start Date ใน Section 2: Administrator Account
- ใส่ `TextFormField(readOnly: true, onTap: _openStartDatePicker, controller: _adminStartDateController, validator: _validateRequired, prefixIcon: Icons.calendar_today)`
- วางก่อนช่อง Password ตามที่ระบุ

4) ส่งค่าไป API
- ใน `_performRegistration()` เพิ่มฟิลด์:
```dart
'adminStartDate': _adminStartDateController.text.isNotEmpty
  ? _adminStartDateController.text
  : DateTime.now().toString().substring(0, 10),
```

5) บังคับกรอกครบก่อนสมัคร
- ช่อง Start Date ใช้ `validator: _validateRequired` จึงต้องมีค่า
- `_registerOrganization()` ใช้ `_formKey.currentState!.validate()` อยู่แล้ว → ป้องกันการกดสมัครหากช่องใดไม่ครบ

## การทดสอบ
- แตะช่อง Start Date → เปิด Bottom Sheet และเลือกได้
- กด “ใช้วันที่นี้” → ช่องแสดงค่า YYYY-MM-DD
- หากเว้นว่าง → กดสมัครแล้วแจ้งเตือน (validator ทำงาน)
- ส่ง API มีฟิลด์ `adminStartDate` ครบถ้วน

อนุมัติแล้วจะลงมือแก้โค้ดตามขั้นตอนนี้และตรวจสอบด้วย flutter analyze ให้ผ่าน