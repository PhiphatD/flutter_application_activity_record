import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/activity_card.dart'; // <--- Import การ์ดใหม่
import '../profile/profile_screen.dart'; // <--- Import ProfileScreen
import 'package:intl/intl.dart';
import 'package:flutter_application_activity_record/theme/app_colors.dart';

// --- (ใหม่) 1. สร้าง Class Model สำหรับเก็บข้อมูล ---
// (ใช้เก็บข้อมูลที่ดึงมาจาก Database หรือ List)
class _Activity {
  final String id;
  final String type;
  final String title;
  final String location;
  final String organizer;
  final int points;
  final int currentParticipants;
  final int maxParticipants;
  final bool isCompulsory;
  final DateTime activityDate; // Key สำหรับจัดกลุ่ม

  _Activity({
    required this.id,
    required this.type,
    required this.title,
    required this.location,
    required this.organizer,
    required this.points,
    required this.currentParticipants,
    required this.maxParticipants,
    required this.isCompulsory,
    required this.activityDate,
  });
}

// --- (เหมือนเดิม) ---
class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  bool _showOnlyFavorites = false; // State สำหรับปุ่ม Favorite
  String _selectedFilter = 'Type'; // State สำหรับปุ่ม Filter

  // --- (ใหม่) 2. List ข้อมูลจำลอง (แทน Database) ---
  // (ย้ายข้อมูลที่เคย Hard-code ใน UI มาไว้ตรงนี้)
  final List<_Activity> _mockActivities = [
    _Activity(
      id: '10',
      type: 'Training',
      title: 'ฝึกอบรม กลยุทธ์การสร้างแบรนด์',
      location: 'ห้องประชุม A3-403 at : 13.00 PM',
      organizer: 'Thanuay',
      points: 200,
      currentParticipants: 20,
      maxParticipants: 40,
      isCompulsory: false,
      activityDate: DateTime(2025, 7, 23),
    ),
    _Activity(
      id: '11',
      type: 'Seminar',
      title: 'งานสัมนาเทคโนโลยีรอบตัวเรา',
      location: 'ห้องประชุม B6-310 at : 14.00 PM',
      organizer: 'Thanuay',
      points: 300,
      currentParticipants: 12,
      maxParticipants: 40,
      isCompulsory: true,
      activityDate: DateTime(2025, 7, 23), // วันที่เดียวกัน
    ),
    _Activity(
      id: '12',
      type: 'Workshop',
      title: 'Workshop Microsoft365',
      location: 'ห้องประชุม C9-203 at : 11.00 AM',
      organizer: 'Thanuay',
      points: 500,
      currentParticipants: 40,
      maxParticipants: 40,
      isCompulsory: false,
      activityDate: DateTime(2026, 1, 24), // คนละวัน
    ),
    // (ข้อมูลนี้ผมเพิ่มให้จากรอบที่แล้วเพื่อให้เห็นการ์ดอีกใบ)
    _Activity(
      id: '4',
      type: 'Training',
      title: 'ฝึกอบรม กลยุทธ์การสร้างแบรนด์ 2',
      location: 'ห้องประชุม A3-403 at : 13.00 PM',
      organizer: 'Thanuay',
      points: 200,
      currentParticipants: 0,
      maxParticipants: 40,
      isCompulsory: false,
      activityDate: DateTime(2026, 1, 31), // คนละวัน
    ),
  ];

  // (ใหม่) 3. ตัวแปรสำหรับเก็บข้อมูลที่ "จัดกลุ่ม" แล้ว
  Map<DateTime, List<_Activity>> _groupedActivities = {};

  // (ใหม่) 4. initState จะทำงานตอนเปิดหน้า
  @override
  void initState() {
    super.initState();
    // จำลองการโหลดข้อมูลและจัดกลุ่ม
    _loadAndGroupActivities();
  }

  // (ใหม่) 5. ฟังก์ชันสำหรับโหลดและจัดกลุ่มข้อมูล (นี่คือส่วนที่จำลองการดึง DB)
  void _loadAndGroupActivities() {
    // ในอนาคต คุณจะดึงข้อมูลจาก API หรือ DB ตรงนี้
    // ตอนนี้เราใช้ _mockActivities แทน

    // 1. เรียงลำดับข้อมูลตามวันที่ (เก่าไปใหม่)
    _mockActivities.sort((a, b) => a.activityDate.compareTo(b.activityDate));

    // 2. จัดกลุ่มข้อมูล
    Map<DateTime, List<_Activity>> groups = {};
    for (var activity in _mockActivities) {
      // เราใช้ "วัน" เป็น key (ไม่สนใจ "เวลา" ในการจัดกลุ่ม)
      final dateKey = DateTime(
        activity.activityDate.year,
        activity.activityDate.month,
        activity.activityDate.day,
      );

      // ถ้ายังไม่มีกลุ่มสำหรับวันนี้ ให้สร้างกลุ่มใหม่
      if (groups[dateKey] == null) {
        groups[dateKey] = [];
      }

      // เพิ่มกิจกรรมนี้เข้าไปในกลุ่มของวันนั้น
      groups[dateKey]!.add(activity);
    }

    // 3. อัปเดต State เพื่อให้หน้าจอ re-build
    setState(() {
      _groupedActivities = groups;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: employeeBg,
      body: SafeArea(
        child: Column(
          children: [
            // --- 1. Custom AppBar (เหมือนเดิม) ---
            _buildCustomAppBar(),

            // --- 2. Search Bar (เหมือนเดิม) ---
            _buildSearchBar(),

            // --- 3. Filter Section (เหมือนเดิม) ---
            _buildFilterSection(),

            // --- 4. (แก้ไข) Activity List ---
            Expanded(
              // (แก้ไข) เปลี่ยนจาก ListView -> ListView.builder
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 10.0,
                ),
                // (แก้ไข) นับจำนวน "วัน" (กลุ่ม) ที่มีกิจกรรม
                itemCount: _groupedActivities.keys.length,
                itemBuilder: (context, index) {
                  // (แก้ไข) ดึง "วันที่" (Key) และ "List กิจกรรม" (Value)
                  final date = _groupedActivities.keys.elementAt(index);
                  final activitiesOnThisDate = _groupedActivities[date]!;

                  // (แก้ไข) เรียก _buildActivityGroup 1 ครั้ง ต่อ 1 วัน
                  return _buildActivityGroup(
                    activityDate: formatActivityDate(date),
                    relativeDate: getRelativeDateString(date),
                    // (แก้ไข) ส่ง List<_Activity> เข้าไป
                    cards: activitiesOnThisDate,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widget สำหรับ Custom AppBar (เหมือนเดิม) ---
  Widget _buildCustomAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // รูปโปรไฟล์
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            child: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey.shade200,
              // TODO: ใส่รูปจริง
              backgroundImage: NetworkImage(
                'https://i.pravatar.cc/150?img=32',
              ), // <--- รูปตัวอย่าง
            ),
          ),

          // ชื่อหน้า "Activity"
          Text(
            'Activity',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF375987),
            ),
          ),

          // ไอคอนแจ้งเตือน
          IconButton(
            icon: Icon(
              Icons.notifications_outlined,
              color: Colors.black54,
              size: 28,
            ),
            onPressed: () {
              // TODO: เปิดหน้า Notification
            },
          ),
        ],
      ),
    );
  }

  // --- Widget สำหรับ Search Bar (เหมือนเดิม) ---
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 255, 255, 255),
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search activities...',
            hintStyle: GoogleFonts.poppins(),
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 15.0,
            ),
          ),
        ),
      ),
    );
  }

  // --- Widget สำหรับแถบ Filter (เหมือนเดิม) ---
  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        children: [
          // --- Filter Pills ---
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterPill('Type'),
                  _buildFilterPill('Date'),
                  _buildFilterPill('Location'),
                ],
              ),
            ),
          ),

          // --- ปุ่ม Favorite (Toggle) ---
          IconButton(
            icon: Icon(
              _showOnlyFavorites ? Icons.favorite : Icons.favorite_border,
              color: _showOnlyFavorites ? Colors.red : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _showOnlyFavorites = !_showOnlyFavorites;
                // TODO: เพิ่ม Logic การกรองรายการโปรด
              });
            },
          ),
        ],
      ),
    );
  }

  // --- Widget ย่อยสำหรับสร้าง Filter Pill (เหมือนเดิม) ---
  Widget _buildFilterPill(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(width: 8.0),
          const Icon(
            Icons.keyboard_arrow_down,
            color: Colors.black87,
            size: 20,
          ),
        ],
      ),
    );
  }

  // --- 6. (แก้ไข) Widget for grouping activities (ใช้ Logic แบบ todo_screen.dart) ---
  Widget _buildActivityGroup({
    required String activityDate,
    required String relativeDate,
    required List<_Activity>
    cards, // <-- (แก้ไข) เปลี่ยน Type เป็น List<_Activity>
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. ส่วนหัวของวันที่ (ใช้ Style และ ระยะห่าง แบบ todo_screen.dart)
        Padding(
          // (สำคัญ) ระยะห่างบน 16, ล่าง 8 (เหมือน todo_screen.dart)
          padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                activityDate,
                // (สำคัญ) ใช้ Style แบบ todo_screen.dart
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 12), // (เหมือน todo_screen.dart)
              Text(
                relativeDate,
                // (สำคัญ) ใช้ Style แบบ todo_screen.dart
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
          ),
        ),

        // 2. ส่วนของการ์ด (ใช้ Logic แบบ todo_screen.dart)
        Column(
          // ใช้ List.generate เพื่อสร้าง List ของ Widgets
          children: List.generate(cards.length, (index) {
            final activity = cards[index];

            // สร้างการ์ดขึ้นมาก่อน
            final cardWidget = ActivityCard(
              id: activity.id,
              type: activity.type,
              title: activity.title,
              location: activity.location,
              organizer: activity.organizer,
              points: activity.points,
              currentParticipants: activity.currentParticipants,
              maxParticipants: activity.maxParticipants,
              isCompulsory: activity.isCompulsory,
            );

            // (สำคัญ) Logic ในการเว้นวรรคแบบ todo_screen.dart
            if (index == 0) {
              // ถ้าเป็นการ์ดใบแรก (index == 0) ของกลุ่ม -> ไม่ต้องเพิ่ม Padding
              return cardWidget;
            } else {
              // ถ้าเป็นการ์ดใบถัดไป -> ให้เพิ่ม Padding(top: 16.0)
              return Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: cardWidget,
              );
            }
          }),
        ),
      ],
    );
  }
}

// --- ฟังก์ชันที่ 1: สำหรับจัดรูปแบบวันที่ (เหมือนเดิม) ---
String formatActivityDate(DateTime eventDate) {
  // 'd MMMM y' คือการจัดรูปแบบ (เช่น 23 July 2025)
  // 'en_US' เพื่อบังคับให้เป็นชื่อเดือนภาษาอังกฤษ (July)
  final formatter = DateFormat('d MMMM y', 'en_US');
  return formatter.format(eventDate);
}

// --- ฟังก์ชันที่ 2: สำหรับคำนวณระยะเวลาที่เหลือ (เหมือนเดิม) ---
String getRelativeDateString(DateTime eventDate) {
  final now = DateTime.now();
  // ล้างค่าเวลา (ชั่วโมง, นาที) เพื่อเปรียบเทียบเฉพาะ "วัน"
  final today = DateTime(now.year, now.month, now.day);
  final cleanEventDate = DateTime(
    eventDate.year,
    eventDate.month,
    eventDate.day,
  );

  // คำนวณส่วนต่างของวัน
  final differenceInDays = cleanEventDate.difference(today).inDays;

  if (differenceInDays < 0) {
    return "Past Event"; // กิจกรรมที่ผ่านมาแล้ว
  } else if (differenceInDays == 0) {
    return "Today"; // วันนี้
  } else if (differenceInDays == 1) {
    return "Tomorrow"; // พรุ่งนี้
  } else if (differenceInDays <= 7) {
    return "This Week"; // ภายใน 7 วัน
  } else if (differenceInDays <= 30) {
    return "This Month"; // ภายใน 30 วัน
  } else if (differenceInDays <= 60) {
    return "Next 2 Months"; // ภายใน 60 วัน (ตรงกับตัวอย่าง)
  } else if (differenceInDays <= 90) {
    return "Next 3 Months"; // ภายใน 90 วัน
  } else {
    // ถ้าไกลกว่า 3 เดือน
    final formatter = DateFormat('MMMM y', 'en_US'); // "July 2025"
    return "in ${formatter.format(eventDate)}";
  }
}
