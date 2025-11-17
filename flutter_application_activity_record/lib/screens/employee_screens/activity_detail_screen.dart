// ไฟล์: lib/screens/employee_screens/activity_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
// (สำคัญ) เราจะ import แค่ 'enum' จากไฟล์อื่น ไม่ import Model
import 'todo_activity_card.dart' show ActivityStatus;

// --- (ใหม่) 1. สร้าง Model "ฉบับเต็ม" สำหรับหน้านี้โดยเฉพาะ ---
// (Model นี้จะไม่ยุ่งเกี่ยวกับ _TodoActivity ใน todo_screen.dart)
class ActivityDetail {
  final String id;
  final String type;
  final String title;
  final String location;
  final String organizer;
  final int points;
  final DateTime activityDate;
  final ActivityStatus status;

  // (Fields ฉบับเต็ม)
  final String guestSpeaker;
  final String eventHost;
  final String organizerContact;
  final String department;
  final String participationFee;
  final String description;
  final bool isRegistered; // <--- (สำคัญ) เพิ่มสถานะการลงทะเบียน

  ActivityDetail({
    required this.id,
    required this.type,
    required this.title,
    required this.location,
    required this.organizer,
    required this.points,
    required this.activityDate,
    required this.status,
    // ---
    required this.guestSpeaker,
    required this.eventHost,
    required this.organizerContact,
    required this.department,
    required this.participationFee,
    required this.description,
    required this.isRegistered,
  });
}

// --- (ใหม่) 2. สร้าง "Database จำลอง" สำหรับหน้า Detail ---
// (นี่คือส่วนที่ "ค้นหาเอง" โดยใช้ ID)
final Map<String, ActivityDetail> _mockDetailDatabase = {
  '1': ActivityDetail(
    id: '1',
    type: 'Workshop',
    title: 'Workshop Excel',
    location: 'ห้องประชุม C9-510 at 14.00 PM',
    organizer: 'Thanuay',
    points: 300,
    activityDate: DateTime(2025, 4, 2),
    status: ActivityStatus.attended,
    guestSpeaker: 'Mr. John Doe',
    eventHost: 'Microsoft Thailand',
    organizerContact: 'tanuay@example.com',
    department: 'All Departments',
    participationFee: 'Free',
    description:
        'เรียนรู้การใช้งาน Excel ขั้นสูง ตั้งแต่ Pivot Table, VLOOKUP จนถึงการสร้าง Dashboard เพื่อการวิเคราะห์ข้อมูลอย่างมีประสิทธิภาพ',
    isRegistered: false, // กิจกรรมจบไปแล้ว
  ),
  '2': ActivityDetail(
    id: '2',
    type: 'Training',
    title: 'งานสัมนา การทำงานร่วมกันในองค์กร',
    location: 'ห้องประชุม C2-310 at 10.30 AM',
    activityDate: DateTime(2024, 7, 23),
    organizer: 'Thanuay',
    points: 100,
    status: ActivityStatus.attended,
    guestSpeaker: 'ดร. ณัฐพงษ์ แสนจันทร์',
    eventHost: 'คณะ IT ม.กรุงเทพ',
    organizerContact: 'hr@bu.ac.th',
    department: 'IT, CS, DS',
    participationFee: 'Free',
    description:
        'เรียนรู้วิธีการทำงานร่วมกับผู้อื่น การสื่อสารในองค์กร และการสร้างวัฒนธรรมองค์กรที่ดี',
    isRegistered: false, // กิจกรรมจบไปแล้ว
  ),
  '3': ActivityDetail(
    id: '3',
    type: 'Seminar',
    title: 'Seminar: New Marketing Trends',
    location: 'Online',
    organizer: 'Marketing Dept',
    points: 150,
    activityDate: DateTime(2024, 3, 15),
    status: ActivityStatus.unattended,
    guestSpeaker: 'Ms. Jane Smith',
    eventHost: 'Digital Marketing Assoc.',
    organizerContact: 'mkt@example.com',
    department: 'Marketing',
    participationFee: '1,500 THB',
    description: 'อัปเดตเทรนด์การตลาดยุคใหม่ AI, Influencer และอื่นๆ',
    isRegistered: false, // กิจกรรมจบไปแล้ว
  ),
  '4': ActivityDetail(
    id: '4',
    type: 'Training',
    title: 'ฝึกอบรม กลยุทธ์การสร้างแบรนด์ 2',
    location: 'ห้องประชุม A3-403 at 13.00 PM',
    organizer: 'Yingying',
    points: 200,
    activityDate: DateTime.now().add(const Duration(days: 10)),
    status: ActivityStatus.upcoming,
    guestSpeaker: 'คุณพิพัฒน์ ดีพื้น',
    eventHost: 'BrandThink',
    organizerContact: 'ying@example.com',
    department: 'All Departments',
    participationFee: 'Free',
    description: 'ต่อยอดจากการสร้างแบรนด์ครั้งที่ 1... (รายละเอียด)',
    isRegistered: true, // <--- (สมมติ) เราลงทะเบียนอันนี้ไว้แล้ว
  ),
  // (เพิ่ม) 5. กิจกรรมที่ยังไม่มาถึง และ "ยังไม่ลงทะเบียน"
  '5': ActivityDetail(
    id: '5', // (คุณต้องเพิ่ม ID นี้ใน todo_screen.dart ด้วย)
    type: 'Seminar',
    title: 'การบรรยายพิเศษ: อนาคตของ AI',
    location: 'ห้องประชุมใหญ่',
    organizer: 'Admin',
    points: 150,
    activityDate: DateTime.now().add(const Duration(days: 20)),
    status: ActivityStatus.upcoming,
    guestSpeaker: 'Mr. Satya Nadella (Simulation)',
    eventHost: 'OpenAI x BU',
    organizerContact: 'admin@bu.ac.th',
    department: 'All Students/Staff',
    participationFee: 'Free',
    description: 'การบรรยายสุดพิเศษเกี่ยวกับอนาคตของ AI และผลกระทบต่อโลก',
    isRegistered: false, // <--- (สำคัญ) ยังไม่ได้ลงทะเบียน
  ),
  '10': ActivityDetail(
    id: '10',
    type: 'Training',
    title: 'ฝึกอบรม กลยุทธ์การสร้างแบรนด์',
    location: 'ห้องประชุม A3-403 at : 13.00 PM',
    organizer: 'Thanuay',
    points: 200,
    activityDate: DateTime(2025, 7, 23),
    status: ActivityStatus.upcoming,
    guestSpeaker: 'คุณ พิพัฒน์ ดีพื้น',
    eventHost: 'BrandThink',
    organizerContact: 'thanuay@example.com',
    department: 'All Departments',
    participationFee: 'Free',
    description: 'หลักการและกลยุทธ์สร้างแบรนด์ให้แข็งแรง พร้อมกรณีศึกษา',
    isRegistered: false,
  ),
  '11': ActivityDetail(
    id: '11',
    type: 'Seminar',
    title: 'งานสัมนาเทคโนโลยีรอบตัวเรา',
    location: 'ห้องประชุม B6-310 at : 14.00 PM',
    organizer: 'Thanuay',
    points: 300,
    activityDate: DateTime(2025, 7, 23),
    status: ActivityStatus.upcoming,
    guestSpeaker: 'วิทยากรรับเชิญด้านเทคโนโลยี',
    eventHost: 'คณะ IT ม.กรุงเทพ',
    organizerContact: 'it@bu.ac.th',
    department: 'IT, CS, DS',
    participationFee: 'Free',
    description: 'สำรวจเทคโนโลยีรอบตัวและผลกระทบต่อองค์กรและชีวิตประจำวัน',
    isRegistered: false,
  ),
  '12': ActivityDetail(
    id: '12',
    type: 'Workshop',
    title: 'Workshop Microsoft365',
    location: 'ห้องประชุม C9-203 at : 11.00 AM',
    organizer: 'Thanuay',
    points: 500,
    activityDate: DateTime(2026, 1, 24),
    status: ActivityStatus.upcoming,
    guestSpeaker: 'Microsoft Thailand',
    eventHost: 'Microsoft Thailand',
    organizerContact: 'ms365@example.com',
    department: 'All Departments',
    participationFee: 'Free',
    description: 'เรียนรู้การใช้งาน Microsoft365 เชิงลึกสำหรับงานองค์กร',
    isRegistered: false,
  ),
};

// -----------------------------------------------------------------

class ActivityDetailScreen extends StatefulWidget {
  final String activityId;
  const ActivityDetailScreen({Key? key, required this.activityId})
    : super(key: key);
  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  // (แก้ไข) 3. ใช้ Model ใหม่
  ActivityDetail? _activityData;
  bool _isLoading = true;

  // (เพิ่ม) 4. State สำหรับปุ่ม (แยกจาก Model)
  late bool _isRegistered;
  bool _isFavorited = false; // State ปุ่มหัวใจ

  @override
  void initState() {
    super.initState();
    _fetchActivityDetails();
  }

  // (แก้ไข) 5. ฟังก์ชัน Fetch ข้อมูล (ค้นหาจาก _mockDetailDatabase)
  Future<void> _fetchActivityDetails() async {
    setState(() {
      _isLoading = true;
    });
    await Future.delayed(const Duration(milliseconds: 500)); // จำลองการโหลด

    final data = _mockDetailDatabase[widget.activityId];

    setState(() {
      _activityData = data;
      _isLoading = false;
      // (สำคัญ) ตั้งค่าสถานะปุ่มตามข้อมูลที่ดึงมาได้
      if (data != null) {
        _isRegistered = data.isRegistered;
      }
    });
  }

  // --- (ใหม่) 6. ฟังก์ชันสำหรับจัดการปุ่ม ---
  void _registerForActivity() {
    setState(() {
      _isRegistered = true;
    });
    // TODO: เรียก API เพื่อลงทะเบียน
    print("API: Registering for ${widget.activityId}...");
  }

  void _cancelRegistration() {
    setState(() {
      _isRegistered = false;
    });
    // TODO: เรียก API เพื่อยกเลิก
    print("API: Cancelling registration for ${widget.activityId}...");
  }

  // -----------------------------------------------------------------
  // (ส่วน Build และ Widgets ย่อย)
  // -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomActionButton(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_activityData == null) {
      return const Center(child: Text("Error: Activity not found."));
    }

    // (แก้ไข) 7. แสดงผลข้อมูลฉบับเต็ม
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildTimeInfo(),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // --- แสดงผล Details ---
          _buildDetailItem(
            Icons.person_outline,
            'Guest Speaker',
            _activityData!.guestSpeaker,
          ),
          _buildDetailItem(
            Icons.business_outlined,
            'Event Host',
            _activityData!.eventHost,
          ),
          _buildDetailItem(
            Icons.support_agent_outlined,
            'Organizer',
            _activityData!.organizer,
          ),
          _buildDetailItem(
            Icons.email_outlined,
            'Organizer Contact',
            _activityData!.organizerContact,
          ),
          _buildDetailItem(
            Icons.apartment_outlined,
            'Department',
            _activityData!.department,
          ),
          _buildDetailItem(
            Icons.confirmation_number_outlined,
            'Participation Fee',
            _activityData!.participationFee,
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // --- แสดง Description ---
          Text(
            'About this activity',
            style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _activityData!.description,
            style: GoogleFonts.kanit(
              fontSize: 15,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // (แก้ไข) 8. ปุ่มล่าง (ควบคุมด้วย Logic ที่คุณต้องการ)
  Widget _buildBottomActionButton() {
    if (_isLoading || _activityData == null) {
      return const SizedBox.shrink();
    }

    // Logic: กิจกรรมจบไปหรือยัง?
    bool isEventPassed =
        _activityData!.status == ActivityStatus.attended ||
        _activityData!.status == ActivityStatus.unattended;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- Logic การแสดงปุ่ม ---

          // 1. ถ้ากิจกรรมจบไปแล้ว (ปุ่มเทา)
          if (isEventPassed)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.grey[600],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                onPressed: null, // <--- Disabled
                child: Text(
                  'Event Finished',
                  style: GoogleFonts.kanit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          // 2. ถ้ากิจกรรมยังไม่จบ และ "ลงทะเบียนแล้ว" (ปุ่มยกเลิก)
          else if (_isRegistered)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                onPressed: _cancelRegistration, // <--- เรียกฟังก์ชันยกเลิก
                child: Text(
                  'Cancel Registration',
                  style: GoogleFonts.kanit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          // 3. (Default) กิจกรรมยังไม่จบ และ "ยังไม่ลงทะเบียน" (ปุ่มลงทะเบียน)
          else
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A80FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                onPressed: _registerForActivity, // <--- เรียกฟังก์ชันลงทะเบียน
                child: Text(
                  'Register for Activity',
                  style: GoogleFonts.kanit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Widgets ย่อย (เหมือนเดิม) ---
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'Activity',
        style: GoogleFonts.kanit(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(
            _isFavorited ? Icons.favorite : Icons.favorite_border,
            color: _isFavorited ? Colors.red : Colors.grey,
            size: 28,
          ),
          onPressed: () {
            setState(() {
              _isFavorited = !_isFavorited;
            });
          },
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                _activityData!.title,
                style: GoogleFonts.kanit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 6.0,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFE6EFFF),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                '${_activityData!.points} Points',
                style: GoogleFonts.kanit(
                  color: const Color(0xFF4A80FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Text(
            'TYPE: ${_activityData!.type}',
            style: GoogleFonts.kanit(
              color: Colors.black54,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              color: Color(0xFF4A80FF),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _activityData!.location,
                style: GoogleFonts.kanit(fontSize: 15, color: Colors.black87),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeInfo() {
    String formattedDate = DateFormat(
      'd MMMM yyyy',
      'en_US',
    ).format(_activityData!.activityDate);
    String formattedTime = DateFormat(
      'HH:mm a',
    ).format(_activityData!.activityDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                color: Colors.grey[700],
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                formattedDate,
                style: GoogleFonts.kanit(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Icon(
                Icons.access_time_outlined,
                color: Colors.grey[700],
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                formattedTime,
                style: GoogleFonts.kanit(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey[600], size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.kanit(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.kanit(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
