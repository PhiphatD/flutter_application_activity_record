import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'activity_card.dart'; // <--- Import การ์ดใหม่

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
                  // --- Card 1 (Normal) ---
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

                  // --- Card 2 (Compulsory) ---
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

                  // --- Card 3 (ตัวอย่างเต็ม) ---
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
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.grey.shade200,
            // child: Icon(Icons.person, color: Colors.grey.shade400),
            // TODO: ใส่รูปจริง
            backgroundImage: NetworkImage(
              'https://i.pravatar.cc/150?img=32',
            ), // <--- รูปตัวอย่าง
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
}
