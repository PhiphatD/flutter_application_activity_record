## เป้าหมาย
- ปรับ `organizer_profile_screen.dart` ให้ใช้รูปแบบการแสดงผลและโครงสร้าง API เดียวกับ `employee_screens/profile/profile_screen.dart`
- แสดงข้อมูล: Company, ชื่อ-คำนำหน้า, Position, Department, QR พร้อมตัวจับเวลา, ส่วนข้อมูลล่าง (Email/Phone/Start Date/Duration) และคัดลอกข้อมูล
- ใช้ `AppBar.bottom` แสดงรหัส ID แบบตรึงไม่ทับหัวข้อ

## แนวทาง
- คงธีมสี/ภาพพื้นหลังของ Organizer ไว้ได้ แต่โครงสร้าง UI และการดึงข้อมูลจะเหมือน Employee
- ใช้ endpoint เดียวกัน: `GET {apiUrl}/employees/{empId}` พร้อม `SharedPreferences('empId')`

## รายการแก้ที่ไฟล์ organizer_profile_screen.dart
1) ปรับตัวแปรสถานะให้สอดคล้องกับ Employee
```dart
// เดิม: orgName, organizerId, organizerRole, organizerDepartment, companyName...
// ปรับเป็นชุดเดียวกันเพื่อความสอดคล้อง
String empName = "Loading...";
String empTitle = "";
String empId = "...";
String empPosition = "...";
String empDepartment = "...";
String companyName = "...";
String avatarUrl = "https://i.pravatar.cc/150?img=32"; // คง placeholder
String qrData = "";

// ส่วนล่าง
String empEmail = "-";
String empPhone = "-";
String empStartDateFormatted = "-";
String serviceDuration = "-";

// Timer/Duration รักษาไว้
late Timer _timer;
Duration _duration = const Duration(minutes: 10);
```

2) ใช้ `AppBar.bottom` แบบเดียวกับ Employee
```dart
appBar: AppBar(
  backgroundColor: topGradientColor,
  // ...
  title: const Text('Organizer Profile', ...),
  centerTitle: true,
  bottom: PreferredSize(
    preferredSize: const Size.fromHeight(72),
    child: Column(
      children: [
        const Text('Organizer ID', style: TextStyle(fontSize: 16, color: Color(0xFF375987))),
        Text(empId, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF375987))),
        const SizedBox(height: 8),
        // เส้นแบ่งเหมือน Employee
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 180),
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF375987).withOpacity(0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    ),
  ),
)
```

3) ปรับฟังก์ชันโหลดข้อมูลให้ตรงกับ Employee
```dart
Future<void> _fetchOrganizerProfile() async {
  final prefs = await SharedPreferences.getInstance();
  final String? storedEmpId = prefs.getString('empId');
  if (storedEmpId == null) return;

  try {
    final response = await http.get(Uri.parse('$apiUrl/employees/$storedEmpId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        empId = data['EMP_ID'] ?? storedEmpId;
        empTitle = data['EMP_TITLE_EN'] ?? "";
        empName = data['EMP_NAME_EN'] ?? "Unknown";
        empPosition = data['EMP_POSITION'] ?? "-";
        empDepartment = data['DEP_NAME'] ?? "-";
        companyName = data['COMPANY_NAME'] ?? "-";
        empEmail = data['EMP_EMAIL'] ?? "-";
        empPhone = data['EMP_PHONE'] ?? "-";
        qrData = empId;
        if (data['EMP_STARTDATE'] != null) {
          final startDate = DateTime.parse(data['EMP_STARTDATE']);
          empStartDateFormatted = DateFormat('d MMM y').format(startDate);
          _calculateServiceDuration(startDate);
        }
      });
    }
  } catch (e) {
    print('Error fetching organizer profile: $e');
  }
}
```

4) เพิ่มฟังก์ชันคำนวณระยะเวลางานและคัดลอกข้อมูล
```dart
void _calculateServiceDuration(DateTime startDate) { /* เทียบ employee */ }
void _copyToClipboard(String text, String label) { /* เทียบ employee */ }
```

5) ปรับโครงสร้าง `body`
- ใช้ `SafeArea` + `Stack` + `SingleChildScrollView` เหมือน Employee
- ลบ Header ID เดิมใน body (เพื่อไม่ซ้ำกับ AppBar.bottom)

6) ปรับ Card/UI ให้สอดคล้อง
- `_buildInfoCard()`:
  - แสดง `companyName`, avatar, `'$empTitle $empName'`, `Position : $empPosition`, `Department : $empDepartment`
  - คงภาพพื้นหลังของ Organizer (`assets/images/card_background_oganize.png`) ได้
- `_buildQrCard()`:
  - ใช้ `QrImageView(data: qrData)` และตัวจับเวลา `_formatDuration(_duration)` เหมือน Employee
- เพิ่มส่วนล่าง `_buildInfoSection()`:
  - Tiles: Email (copy), Phone (call/copy), Start Date + Duration

7) API URL
- คง `final String apiUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";` เหมือนที่อัปเดตแล้ว

## ผลลัพธ์ที่คาดหวัง
- หน้า Organizer จะมีโครงสร้างเหมือน Employee ทุกจุด ทั้งการแสดงข้อมูลและการเรียก API
- ไม่เกิดการทับกับหัวข้อ เพราะย้าย ID ไปไว้ `AppBar.bottom`
- ส่วนข้อมูลล่างสามารถคัดลอก Email/Phone ได้

## การทดสอบ
- เปิดหน้า Organizer และเลื่อน ตรวจสอบ Layout, ค่าแสดงผล, การคัดลอกข้อมูล
- ตรวจสอบ QR refresh ทุก 10 นาทีเหมือน Employee
- รัน `flutter analyze` ให้ผ่าน

ยืนยันแผนนี้หรือให้คงธีมสี/ภาพพื้นหลังแบบ Organizer ตามเดิม? ถ้าโอเค ผมจะลงมือปรับโค้ดตามแผนทันที