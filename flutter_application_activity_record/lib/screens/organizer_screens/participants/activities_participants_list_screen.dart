import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_application_activity_record/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'participants_details_screen.dart';
import '../profile/organizer_profile_screen.dart';
import 'qr_scanner_screen.dart';

class ActivitiesParticipantsListScreen extends StatefulWidget {
  const ActivitiesParticipantsListScreen({super.key});

  @override
  State<ActivitiesParticipantsListScreen> createState() =>
      _ActivitiesParticipantsListScreenState();
}

class _ActivitiesParticipantsListScreenState
    extends State<ActivitiesParticipantsListScreen> {
  final String baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";

  final TextEditingController _search = TextEditingController();
  String _query = '';
  int _selectedTab = 0; // 0=Active, 1=History
  bool _isLoading = true;
  List<_Activity> _activities = [];
  String _currentOrganizerName = "";

  @override
  void initState() {
    super.initState();
    _fetchActivities();
    _search.addListener(() => setState(() => _query = _search.text.trim()));
  }

  Future<void> _fetchActivities() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentOrganizerName = prefs.getString('name') ?? "";

      final response = await http.get(Uri.parse('$baseUrl/activities'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _activities = data.map((json) => _Activity.fromJson(json)).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<DateTime, List<_Activity>> get _filteredAndGrouped {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final filteredList = _activities.where((a) {
      // Filter 1: Organizer (Only mine)
      final isMine = a.organizerName == _currentOrganizerName;
      if (!isMine) return false;

      // Filter 2: Search
      final matchesSearch =
          _query.isEmpty || a.name.toLowerCase().contains(_query.toLowerCase());
      if (!matchesSearch) return false;

      // Filter 3: Date
      final actDate = DateTime(
        a.activityDate.year,
        a.activityDate.month,
        a.activityDate.day,
      );

      if (_selectedTab == 0) {
        return !actDate.isBefore(today);
      } else {
        return actDate.isBefore(today);
      }
    }).toList();

    if (_selectedTab == 0) {
      filteredList.sort((a, b) => a.activityDate.compareTo(b.activityDate));
    } else {
      filteredList.sort((a, b) => b.activityDate.compareTo(a.activityDate));
    }

    Map<DateTime, List<_Activity>> groups = {};
    for (var activity in filteredList) {
      final dateKey = DateTime(
        activity.activityDate.year,
        activity.activityDate.month,
        activity.activityDate.day,
      );
      if (groups[dateKey] == null) groups[dateKey] = [];
      groups[dateKey]!.add(activity);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groupedMap = _filteredAndGrouped;
    final dateKeys = groupedMap.keys.toList();

    return Scaffold(
      backgroundColor: organizerBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildTabs(),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : dateKeys.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: EdgeInsets.only(
                        left: 20.0,
                        right: 20.0,
                        top: 10.0,
                        bottom: 80.0 + MediaQuery.of(context).padding.bottom,
                      ),
                      itemCount: dateKeys.length,
                      itemBuilder: (context, index) {
                        final date = dateKeys[index];
                        final activitiesOnDate = groupedMap[date]!;
                        return _buildActivityGroup(
                          date: date,
                          cards: activitiesOnDate,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No activities found",
            style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  // [UPDATED] Helper สำหรับข้อความ Relative Date (Today, This Week)
  String _getRelativeDateString(DateTime eventDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cleanEventDate = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
    );
    final differenceInDays = cleanEventDate.difference(today).inDays;

    if (differenceInDays == 0) return "Today";
    if (differenceInDays == 1) return "Tomorrow";
    if (differenceInDays > 1 && differenceInDays <= 7) return "This Week";
    if (differenceInDays > 7 && differenceInDays <= 30) return "This Month";

    // ถ้าเป็นอดีต
    if (differenceInDays < 0 && differenceInDays >= -7) return "Last Week";

    return "";
  }

  // [UPDATED] Group Header Layout
  Widget _buildActivityGroup({
    required DateTime date,
    required List<_Activity> cards,
  }) {
    final relativeDate = _getRelativeDateString(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.baseline, // จัดให้ตัวหนังสือวางแนวเดียวกัน
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                // Format: "Tue, 25 Nov 2025"
                DateFormat('EEE, d MMM y', 'en_US').format(date),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16, // ปรับขนาดให้ใหญ่ขึ้นนิดหน่อยตามรูป
                  color: Colors.black,
                ),
              ),
              if (relativeDate.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  relativeDate,
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
        ...cards
            .map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _EnterpriseActivityCard(
                  activity: a,
                  onTap: () => _navigateToDetail(a),
                  onScan: () => _scanQrDirectly(a),
                ),
              ),
            )
            .toList(),
      ],
    );
  }

  void _navigateToDetail(_Activity a) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParticipantsDetailsScreen(
          activityId: a.actId,
          activityName: a.name,
          activityDate: a.activityDate,
          location: a.location,
        ),
      ),
    );
  }

  void _scanQrDirectly(_Activity a) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    ).then((value) {
      if (value != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Scanned: $value")));
      }
    });
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: SizedBox(
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OrganizerProfileScreen(),
                  ),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: const NetworkImage(
                    'https://i.pravatar.cc/150?img=32',
                  ),
                ),
              ),
            ),
            Center(
              child: Text(
                'My Activities',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF375987),
                ),
              ),
            ),
          ],
        ),
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
          controller: _search,
          decoration: InputDecoration(
            hintText: 'Search my activities...',
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

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        children: [
          _buildTabButton('Active', Icons.event_available, 0),
          const SizedBox(width: 12),
          _buildTabButton('History', Icons.history, 1),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, int index) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFD600) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFD600) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.black : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.black : Colors.grey.shade800,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnterpriseActivityCard extends StatelessWidget {
  final _Activity activity;
  final VoidCallback onTap;
  final VoidCallback onScan;

  const _EnterpriseActivityCard({
    required this.activity,
    required this.onTap,
    required this.onScan,
  });

  String _calculateDuration(String start, String end) {
    if (start == "-" || end == "-") return "";
    try {
      final s = DateFormat("HH:mm").parse(start);
      final e = DateFormat("HH:mm").parse(end);
      final diff = e.difference(s);
      final hours = diff.inHours;
      final minutes = diff.inMinutes.remainder(60);
      if (hours > 0 && minutes > 0) return "${hours}h ${minutes}m";
      if (hours > 0) return "${hours}h";
      return "${minutes}m";
    } catch (_) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayTime = (activity.startTime == "-" || activity.endTime == "-")
        ? "Time TBA"
        : "${activity.startTime} - ${activity.endTime}";
    final duration = _calculateDuration(activity.startTime, activity.endTime);

    String cleanLocation = activity.location;
    if (cleanLocation.contains(" at :")) {
      cleanLocation = cleanLocation.split(" at :")[0].trim();
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // [Row 1] Type & Points (Badge)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    activity.actType,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFFFFF8E1,
                    ), // สีเหลืองอ่อนๆ แบบ Badge คะแนน
                    borderRadius: BorderRadius.circular(20),
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
                        "${activity.point} Pts",
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

            // [Row 2] Title
            Text(
              activity.name,
              style: GoogleFonts.kanit(
                fontSize: 16,
                fontWeight: FontWeight.w600, // เพิ่มน้ำหนักฟอนต์
                color: const Color(0xFF222222),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // [Row 3] Location
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    cleanLocation,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // [Row 4] Time + Duration
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  displayTime,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[800],
                  ),
                ),
                if (duration.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    "($duration)",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 12),

            // [Row 5] Participants Progress Bar (เหมือนหน้า Management)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.people_alt,
                      size: 16,
                      color: const Color(0xFF424242),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "${activity.currentParticipants}/${activity.maxParticipants} Registered",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF424242),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: activity.maxParticipants > 0
                        ? activity.currentParticipants /
                              activity.maxParticipants
                        : 0,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF4A80FF),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Model
class _Activity {
  final String actId;
  final String organizerName;
  final String name;
  final String actType;
  final int point;
  final String location;
  final int currentParticipants;
  final int maxParticipants;
  final String status;
  final DateTime activityDate;
  final String startTime;
  final String endTime;

  _Activity({
    required this.actId,
    required this.organizerName,
    required this.name,
    required this.actType,
    required this.point,
    required this.location,
    required this.currentParticipants,
    required this.maxParticipants,
    required this.status,
    required this.activityDate,
    required this.startTime,
    required this.endTime,
  });

  factory _Activity.fromJson(Map<String, dynamic> json) {
    DateTime date = DateTime.now();
    if (json['activityDate'] != null) {
      date = DateTime.parse(json['activityDate']);
    }
    return _Activity(
      actId: json['actId']?.toString() ?? '',
      organizerName: json['organizerName'] ?? '',
      name: json['name'] ?? '',
      actType: json['actType'] ?? '',
      point: json['point'] ?? 0,
      location: json['location'] ?? '-',
      currentParticipants: json['currentParticipants'] ?? 0,
      maxParticipants: json['maxParticipants'] ?? 0,
      status: json['status'] ?? 'Open',
      activityDate: date,
      startTime: json['startTime'] ?? '-',
      endTime: json['endTime'] ?? '-',
    );
  }
}
