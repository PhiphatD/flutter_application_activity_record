import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'activity_card.dart'; // <--- Import การ์ดใหม่
import 'profile_screen.dart'; // <--- Import ProfileScreen
import 'package:intl/intl.dart';

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  bool _showOnlyFavorites = false; // State สำหรับปุ่ม Favorite
  String _selectedFilter = 'Type'; // State สำหรับปุ่ม Filter

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // --- 1. Custom AppBar ---
            _buildCustomAppBar(),

            // --- 2. Search Bar ---
            _buildSearchBar(),

            // --- 3. Filter Section ---
            _buildFilterSection(),

            // --- 4. Activity List ---
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 10.0,
                ),
                children: [
                  _buildActivityGroup(
                    activityDate: formatActivityDate(DateTime(2025, 7, 23)),
                    relativeDate: getRelativeDateString(DateTime(2025, 7, 23)),
                    cards: Column(
                      children: [
                        const SizedBox(height: 16), // Add space between cards
                        ActivityCard(
                          type: 'Training',
                          title: 'ฝึกอบรม กลยุทธ์การสร้างแบรนด์',
                          location: 'ห้องประชุม A3-403 at : 13.00 PM',
                          organizer: 'Thanuay',
                          points: 200,
                          currentParticipants: 20,
                          maxParticipants: 40,
                          isCompulsory: false,
                        ),
                        SizedBox(height: 16), // Add space between cards
                        ActivityCard(
                          type: 'Seminar',
                          title: 'งานสัมนาเทคโนโลยีรอบตัวเรา',
                          location: 'ห้องประชุม B6-310 at : 14.00 PM',
                          organizer: 'Thanuay',
                          points: 300,
                          currentParticipants: 12,
                          maxParticipants: 40,
                          isCompulsory: true,
                        ),
                      ],
                    ),
                  ),
                  _buildActivityGroup(
                    activityDate: formatActivityDate(DateTime(2026, 1, 24)),
                    relativeDate: getRelativeDateString(DateTime(2026, 1, 24)),
                    cards: Column(
                      children: [
                        const SizedBox(height: 16), // Add space between cards
                        ActivityCard(
                          type: 'Workshop',
                          title: 'Workshop Microsoft365',
                          location: 'ห้องประชุม C9-203 at : 11.00 AM',
                          organizer: 'Thanuay',
                          points: 500,
                          currentParticipants: 40,
                          maxParticipants: 40,
                          isCompulsory: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widget สำหรับ Custom AppBar ---
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
            'Activity',
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

  // --- Widget สำหรับ Search Bar ---
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

  // --- Widget สำหรับแถบ Filter ---
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

  // --- Widget ย่อยสำหรับสร้าง Filter Pill ---
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

  // --- Widget for grouping activities by date ---
  Widget _buildActivityGroup({
    required String activityDate,
    required String relativeDate,
    required Widget cards,
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
                style: const TextStyle(fontSize: 16, color: Colors.black),
              ),
              const SizedBox(width: 16),
              Text(
                relativeDate,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
        cards,
      ],
    );
  }
}

// --- ฟังก์ชันที่ 1: สำหรับจัดรูปแบบวันที่ ---
// Input: DateTime(2025, 7, 23)
// Output: "23 July 2025"
String formatActivityDate(DateTime eventDate) {
  // 'd MMMM y' คือการจัดรูปแบบ (เช่น 23 July 2025)
  // 'en_US' เพื่อบังคับให้เป็นชื่อเดือนภาษาอังกฤษ (July)
  final formatter = DateFormat('d MMMM y', 'en_US');
  return formatter.format(eventDate);
}

// --- ฟังก์ชันที่ 2: สำหรับคำนวณระยะเวลาที่เหลือ ---
// Input: DateTime(2025, 7, 23)
// Output: "Next 2 Months"
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
