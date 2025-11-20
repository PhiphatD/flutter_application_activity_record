import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../profile/profile_screen.dart';
import 'activity_detail_screen.dart';

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  final String baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";
  bool _isLoading = true;
  List<dynamic> _activities = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchActivities();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  Future<void> _fetchActivities() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/activities'));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _activities = json.decode(utf8.decode(response.bodyBytes));
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error fetching activities: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Logic การกรองและจัดกลุ่ม
  Map<String, List<dynamic>> get _groupedActivities {
    Map<String, List<dynamic>> groups = {};

    // กรองตามคำค้นหา
    final filtered = _activities.where((act) {
      final title = (act['name'] ?? '').toString().toLowerCase();
      return title.contains(_searchQuery);
    }).toList();

    // เรียงลำดับวันที่ (ใหม่ -> เก่า หรือ เก่า -> ใหม่ ตามต้องการ)
    filtered.sort((a, b) {
      DateTime dateA =
          DateTime.tryParse(a['activityDate'] ?? '') ?? DateTime.now();
      DateTime dateB =
          DateTime.tryParse(b['activityDate'] ?? '') ?? DateTime.now();
      return dateA.compareTo(dateB);
    });

    for (var act in filtered) {
      final dateStr = act['activityDate'] ?? '';
      if (dateStr.isEmpty) continue;

      DateTime date = DateTime.parse(dateStr);
      String key = DateFormat('yyyy-MM-dd').format(date);

      if (groups[key] == null) groups[key] = [];
      groups[key]!.add(act);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groupedMap = _groupedActivities;
    final dateKeys = groupedMap.keys.toList();

    return Scaffold(
      // [1] ใช้ Stack เพื่อซ้อนพื้นหลัง
      body: Stack(
        children: [
          _buildBackground(), // พื้นหลัง Gradient สีฟ้า
          SafeArea(
            child: Column(
              children: [
                _buildCustomAppBar(),
                _buildSearchBar(),

                // [2] Content List
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : dateKeys.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.only(
                            left: 20.0,
                            right: 20.0,
                            bottom: 20.0,
                          ),
                          itemCount: dateKeys.length,
                          itemBuilder: (context, index) {
                            final dateKey = dateKeys[index];
                            final acts = groupedMap[dateKey]!;
                            return _buildActivityGroup(dateKey, acts);
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white, // บนสุดขาว
            Color(0xFFE6EFFF), // กลางๆ ฟ้าอ่อน (Theme Employee)
            Colors.white, // ล่างขาว
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.3, 0.8],
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: const NetworkImage(
                'https://i.pravatar.cc/150?img=32',
              ),
            ),
          ),
          Text(
            'Activity Feed',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF375987),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: Colors.black54,
              size: 28,
            ),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search activities...',
            hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
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

  Widget _buildActivityGroup(String dateKey, List<dynamic> activities) {
    DateTime date = DateTime.parse(dateKey);
    String dayStr = DateFormat('EEE, d MMM y', 'en_US').format(date);

    // Relative Date Logic
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = date.difference(today).inDays;
    String relative = "";
    if (diff == 0)
      relative = "Today";
    else if (diff == 1)
      relative = "Tomorrow";
    else if (diff > 1 && diff <= 7)
      relative = "This Week";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20.0, bottom: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                dayStr,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
              if (relative.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  relative,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        ...activities
            .map(
              (act) => Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _EmployeeActivityCard(activity: act),
              ),
            )
            .toList(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No activities found",
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// [NEW] Enterprise Grade Card for Employee
class _EmployeeActivityCard extends StatelessWidget {
  final dynamic activity;

  const _EmployeeActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final String name = activity['name'] ?? 'Unknown Activity';
    final String type = activity['actType'] ?? 'General';
    final int points = activity['point'] ?? 0;
    final String location = activity['location'] ?? '-';
    final String startTime = activity['startTime'] ?? '-';
    final String endTime = activity['endTime'] ?? '-';
    final int current = activity['currentParticipants'] ?? 0;
    final int max = activity['maxParticipants'] ?? 0;
    final bool isCompulsory = (activity['isCompulsory'] == 1);
    final String status = activity['status'] ?? 'Open';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActivityDetailScreen(activityId: activity['actId']),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 1), // เส้นขอบ
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08), // เงาฟุ้งแบบผู้ดี
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tags Row
            Row(
              children: [
                _tag(type, Colors.blue.shade50, Colors.blue.shade700),
                const SizedBox(width: 8),
                if (isCompulsory)
                  _tag(
                    "Compulsory",
                    Colors.orange.shade50,
                    Colors.orange.shade700,
                  ),
                const Spacer(),
                // Points Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: Colors.orange.shade800,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "$points Pts",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              name,
              style: GoogleFonts.kanit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF222222),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Info Rows
            _infoRow(Icons.access_time_rounded, "$startTime - $endTime"),
            const SizedBox(height: 4),
            _infoRow(Icons.location_on_outlined, location),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 12),

            // Participants Bar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.people_alt_outlined,
                            size: 16,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$current/$max Registered",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: max > 0 ? current / max : 0,
                          backgroundColor: Colors.grey[100],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF4A80FF),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Status Button / Label
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: status == 'Full'
                        ? Colors.red.shade50
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status == 'Open' ? 'Join Now' : status,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: status == 'Full'
                          ? Colors.red
                          : Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _tag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
