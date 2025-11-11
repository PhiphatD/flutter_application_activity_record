import 'package:flutter/material.dart';
// --- 1. (แก้ไข) Import Card ใหม่ ---
import 'todo_activity_card.dart'; // <--- Import การ์ดใหม่
// --- ------------------------- ---
import 'profile_screen.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
// --- 2. (แก้ไข) ย้าย enum ไปไว้ใน todo_activity_card.dart แล้ว ---
// (ลบ enum ActivityStatus ออกจากหน้านี้)

// --- 3. Model ข้อมูล (เหมือนเดิม) ---
class _TodoActivity {
  final String id;
  final String type;
  final String title;
  final String location;
  final String organizer;
  final int points;
  final DateTime activityDate;
  final ActivityStatus status;

  _TodoActivity({
    required this.id,
    required this.type,
    required this.title,
    required this.location,
    required this.organizer,
    required this.points,
    required this.activityDate,
    required this.status,
  });
}

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  String _selectedFilter = 'History';

  // --- 4. List ข้อมูลจำลอง (เหมือนเดิม) ---
  final List<_TodoActivity> _allActivities = [
    _TodoActivity(
      id: '1',
      type: 'Workshop',
      title: 'Workshop Excel',
      location: 'ห้องประชุม C9-510 at 14.00 PM',
      organizer: 'Thanuay',
      points: 300,
      activityDate: DateTime(2025, 4, 2),
      status: ActivityStatus.attended,
    ),
    _TodoActivity(
      id: '2',
      type: 'Training',
      title: 'งานสัมนา การทำงานร่วมกันในองค์กร',
      location: 'ห้องประชุม C2-310 at 10.30 AM',
      activityDate: DateTime(2024, 7, 23),
      organizer: 'Thanuay',
      points: 100,
      status: ActivityStatus.attended,
    ),
    _TodoActivity(
      id: '3',
      type: 'Seminar',
      title: 'Seminar: New Marketing Trends',
      location: 'Online',
      organizer: 'Marketing Dept',
      points: 150,
      activityDate: DateTime(2024, 3, 15),
      status: ActivityStatus.unattended,
    ),
    _TodoActivity(
      id: '4',
      type: 'Training',
      title: 'ฝึกอบรม กลยุทธ์การสร้างแบรนด์ 2',
      location: 'ห้องประชุม A3-403 at 13.00 PM',
      organizer: 'Yingying',
      points: 200,
      activityDate: DateTime.now().add(const Duration(days: 10)),
      status: ActivityStatus.upcoming,
    ),
  ];

  List<_TodoActivity> _filteredActivities = [];

  @override
  void initState() {
    super.initState();
    _filterActivities();
  }

  // --- 5. Logic กรองข้อมูล (เหมือนเดิม) ---
  void _filterActivities() {
    if (_selectedFilter == 'History') {
      _filteredActivities = _allActivities
          .where((act) => act.status == ActivityStatus.attended)
          .toList();
    } else if (_selectedFilter == 'Unattended') {
      _filteredActivities = _allActivities
          .where((act) => act.status == ActivityStatus.unattended)
          .toList();
    } else if (_selectedFilter == 'Upcoming') {
      _filteredActivities = _allActivities
          .where((act) => act.status == ActivityStatus.upcoming)
          .toList();
    } else {
      _filteredActivities = List.from(_allActivities);
    }

    // --- (สำคัญ) การเรียงลำดับ (ล่าสุดอยู่บนสุด) ---
    _filteredActivities.sort(
      (a, b) => b.activityDate.compareTo(a.activityDate),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomAppBar(),
            _buildSearchBar(),
            _buildFilterSection(),

            // --- 6. (แก้ไข) ListView.builder ---
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 10.0,
                ),
                itemCount: _filteredActivities.length,
                itemBuilder: (context, index) {
                  final activity = _filteredActivities[index];

                  final bool showDateHeader =
                      (index == 0) ||
                      (formatActivityDate(
                            _filteredActivities[index - 1].activityDate,
                          ) !=
                          formatActivityDate(activity.activityDate));

                  // --- 7. (แก้ไข) เรียกใช้ ActivityCard ให้ถูกต้อง ---
                  final activityCard = ActivityCard(
                    type: activity.type,
                    title: activity.title,
                    location: activity.location,
                    organizer: activity.organizer,
                    points: activity.points,
                    status: activity.status,

                    // --- (สำคัญ) ส่งค่า Dummy ไปด้วย ---
                    currentParticipants: 0,
                    maxParticipants: 0,
                    // --- (ลบ) backgroundColor ออก ---
                    // backgroundColor: cardBgColor,
                  );
                  // --- ------------------------------- ---

                  if (showDateHeader) {
                    return _buildActivityGroup(
                      activityDate: formatActivityDate(activity.activityDate),
                      relativeDate: getRelativeDateString(
                        activity.activityDate,
                      ),
                      card: activityCard,
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: activityCard,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 8. (แก้ไข) AppBar (ลบ GoogleFonts) ---
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
              // child: Icon(Icons.person, color: Colors.grey.shade400),
              // TODO: ใส่รูปจริง
              backgroundImage: NetworkImage(
                'https://i.pravatar.cc/150?img=32',
              ), // <--- รูปตัวอย่าง
            ),
          ),

          // ชื่อหน้า "Activity"
          Text(
            'To do',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
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

  // --- 9. (แก้ไข) Search Bar (ลบ GoogleFonts) ---
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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

  // --- 10. (แก้ไข) Filter Section (ลบ GoogleFonts) ---
  // ไฟล์: todo_screen.dart

  // --- 10. (แก้ไข) Filter Section ---
  Widget _buildFilterSection() {
    final List<String> filters = ['Upcoming', 'Unattended', 'History'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Container(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: filters.length,
          itemBuilder: (context, index) {
            final filter = filters[index];
            final bool isSelected = _selectedFilter == filter;

            // --- Logic สีปุ่ม Filter (เหมือนเดิม) ---
            Color selectedColor = const Color(0xFF375987);
            Color labelColor = isSelected ? Colors.white : Colors.black87;
            Color borderColor = isSelected
                ? selectedColor
                : Colors.grey.shade400;

            if (filter == 'History') {
              selectedColor = const Color(0xFF06A710);
              if (isSelected) {
                labelColor = Colors.white;
                borderColor = const Color(0xFF06A710);
              }
            } else if (filter == 'Unattended') {
              selectedColor = const Color(0xFFD91A1A);
              if (isSelected) {
                labelColor = Colors.white;
                borderColor = const Color(0xFFD91A1A);
              }
            }
            // ---------------------------------

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(filter),
                labelStyle: TextStyle(
                  // <-- แก้ฟอนต์
                  color: labelColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                selected: isSelected,
                onSelected: (bool selected) {
                  if (selected) {
                    setState(() {
                      _selectedFilter = filter;
                      _filterActivities(); // <-- กรองข้อมูลใหม่
                    });
                  }
                },
                backgroundColor: Colors.white,
                selectedColor: selectedColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  side: BorderSide(color: borderColor),
                ),
                showCheckmark: false,
              ),
            );
          },
        ),
      ),
    );
    // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  }

  // --- 11. (แก้ไข) ฟังก์ชันเดิม (ลบ GoogleFonts และเปลี่ยน Type) ---
  Widget _buildActivityGroup({
    required String activityDate,
    required String relativeDate,
    required ActivityCard
    card, // <-- 12. (แก้ไข) เปลี่ยน Type เป็น ActivityCard
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                activityDate,
                style: const TextStyle(
                  // <-- แก้ฟอนต์
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                relativeDate,
                style: TextStyle(
                  // <-- แก้ฟอนต์
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
        card,
      ],
    );
  }

  // (ฟังก์ชัน formatActivityDate และ getRelativeDateString ไม่ต้องแก้ไข)

  String formatActivityDate(DateTime eventDate) {
    final formatter = DateFormat('d MMMM y', 'en_US');
    return formatter.format(eventDate);
  }

  String getRelativeDateString(DateTime eventDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cleanEventDate = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
    );
    final differenceInDays = cleanEventDate.difference(today).inDays;

    if (differenceInDays < 0) {
      final daysAgo = differenceInDays.abs();
      if (daysAgo <= 7) return "Last Week";
      if (daysAgo <= 30) return "Last Month";
      return "Past Event";
    }
    if (differenceInDays == 0) return "Today";
    if (differenceInDays == 1) return "Tomorrow";
    if (differenceInDays <= 7) return "This Week";
    if (differenceInDays <= 30) return "This Month";
    return "Upcoming";
  }
}
