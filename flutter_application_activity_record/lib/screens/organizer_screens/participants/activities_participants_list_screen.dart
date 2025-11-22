import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'participants_details_screen.dart';
import '../profile/organizer_profile_screen.dart';
import 'enterprise_scanner_screen.dart';
import 'activities/activity_qr_display_screen.dart';

class ActivitiesParticipantsListScreen extends StatefulWidget {
  const ActivitiesParticipantsListScreen({super.key});

  @override
  State<ActivitiesParticipantsListScreen> createState() =>
      _ActivitiesParticipantsListScreenState();
}

class _ActivitiesParticipantsListScreenState
    extends State<ActivitiesParticipantsListScreen>
    with SingleTickerProviderStateMixin {
  // [NEW] เพิ่ม Mixin

  final String baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";

  final TextEditingController _search = TextEditingController();
  String _query = '';

  // [NEW] ใช้ TabController แทน int selector
  late TabController _tabController;

  bool _isLoading = true;
  List<_Activity> _activities = [];
  String _currentOrganizerName = "";

  @override
  void initState() {
    super.initState();
    // [NEW] Init TabController (2 Tabs: Active, History)
    _tabController = TabController(length: 2, vsync: this);

    _fetchActivities();
    _search.addListener(() => setState(() => _query = _search.text.trim()));
  }

  @override
  void dispose() {
    _tabController.dispose(); // [NEW] Dispose
    _search.dispose();
    super.dispose();
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

  // [UPDATED] ปรับ Logic ให้รับ parameter ว่าจะเอา Active หรือ History
  Map<DateTime, List<_Activity>> _getGroupedActivities(bool isHistory) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final filteredList = _activities.where((a) {
      // 1. Owner Filter (บังคับดูเฉพาะของตัวเอง)
      if (a.organizerName != _currentOrganizerName) return false;

      // 2. Search
      final matchesSearch =
          _query.isEmpty || a.name.toLowerCase().contains(_query.toLowerCase());
      if (!matchesSearch) return false;

      // 3. Time Filter
      final actDate = DateTime(
        a.activityDate.year,
        a.activityDate.month,
        a.activityDate.day,
      );

      if (!isHistory) {
        return !actDate.isBefore(today); // Active (Today + Future)
      } else {
        return actDate.isBefore(today); // History (Past)
      }
    }).toList();

    // Sort
    if (!isHistory) {
      filteredList.sort((a, b) => a.activityDate.compareTo(b.activityDate));
    } else {
      filteredList.sort((a, b) => b.activityDate.compareTo(a.activityDate));
    }

    // Group
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
    return Scaffold(
      body: Stack(
        children: [
          Container(
            color: const Color.fromARGB(255, 255, 255, 255),
          ), // พื้นหลังสีเทาอ่อน
          SafeArea(
            child: Column(
              children: [
                // 1. Header (Profile & Search)
                _buildModernHeader(),

                // 2. Tab Bar (Sliding Style like Todo)
                _buildTabBar(),

                const Divider(height: 1, thickness: 1, color: Colors.black12),

                // 3. Tab View (Content)
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildListContent(isHistory: false), // Active Tab
                            _buildListContent(isHistory: true), // History Tab
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // [NEW] Widget สำหรับแสดงเนื้อหาในแต่ละ Tab
  Widget _buildListContent({required bool isHistory}) {
    final groupedMap = _getGroupedActivities(isHistory);
    final dateKeys = groupedMap.keys.toList();

    if (dateKeys.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
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
          isHistoryTab: isHistory,
        );
      },
    );
  }

  // [NEW] Header แบบกระชับ (ตัด Tab เดิมออก)
  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      color: Colors.white, // ใช้สีพื้นขาวเนียนไปกับ TabBar
      child: Column(
        children: [
          // Row 1: Profile & Title
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OrganizerProfileScreen(),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF4A80FF),
                      width: 2,
                    ),
                  ),
                  child: const CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(
                      'https://i.pravatar.cc/150?img=32',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Check Participants",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF375987),
                    ),
                  ),
                  Text(
                    "Manage check-ins",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.black54,
                ),
                onPressed: () {},
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Row 2: Search Bar
          Container(
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search your activities...',
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey[400],
                  size: 22,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // [NEW] TabBar สไตล์ TodoScreen
  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF4A80FF),
        unselectedLabelColor: Colors.grey[500],
        indicatorColor: const Color(0xFF4A80FF),
        indicatorWeight: 3,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.normal,
        ),
        tabs: const [
          Tab(text: "Active"),
          Tab(text: "History"),
        ],
      ),
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
            style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

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
    if (differenceInDays < 0) return "Past Event";

    return "";
  }

  Widget _buildActivityGroup({
    required DateTime date,
    required List<_Activity> cards,
    required bool isHistoryTab,
  }) {
    final relativeDate = _getRelativeDateString(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  DateFormat('EEE, d MMM y', 'en_US').format(date),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black,
                  ),
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
                child: _ParticipantActivityCard(
                  activity: a,
                  isHistory: isHistoryTab,
                  onTap: () => _navigateToDetail(a, isHistoryTab),
                ),
              ),
            )
            .toList(),
      ],
    );
  }

  void _navigateToDetail(_Activity a, bool isHistory) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParticipantsDetailsScreen(
          activityId: a.actId,
          activityName: a.name,
          activityDate: a.activityDate,
          location: a.location,
          isHistory: isHistory,
          startTime: a.startTime,
          endTime: a.endTime,
          isCompulsory: a.isCompulsory,
        ),
      ),
    );
  }
}

// [CARD] ดีไซน์เดิมที่แก้ไว้แล้ว (ไม่มีปุ่ม Scan)
class _ParticipantActivityCard extends StatelessWidget {
  final _Activity activity;
  final bool isHistory;
  final VoidCallback onTap;

  const _ParticipantActivityCard({
    required this.activity,
    required this.isHistory,
    required this.onTap,
  });

  Color _getTypeColor(String type) {
    if (isHistory) return Colors.grey.shade400;
    switch (type.toLowerCase()) {
      case 'training':
        return const Color(0xFF4A80FF);
      case 'seminar':
        return const Color(0xFFFF9F1C);
      case 'workshop':
        return const Color(0xFF2EC4B6);
      case 'expo':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor(activity.actType);
    final displayTime = (activity.startTime == "-" || activity.endTime == "-")
        ? "Time TBA"
        : "${activity.startTime} - ${activity.endTime}";

    String cleanLocation = activity.location;
    if (cleanLocation.contains(" at :")) {
      cleanLocation = cleanLocation.split(" at :")[0].trim();
    }

    String statusText = activity.status;
    Color statusBg = const Color(0xFFE6EFFF);
    Color statusColor = const Color(0xFF4A80FF);

    if (isHistory) {
      statusText = "Ended";
      statusBg = Colors.grey.shade200;
      statusColor = Colors.grey.shade700;
    }

    double progress = 0;
    if (activity.maxParticipants > 0) {
      progress = (activity.currentParticipants / activity.maxParticipants)
          .clamp(0.0, 1.0);
    }

    return Opacity(
      opacity: isHistory ? 0.7 : 1.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isHistory ? 0.02 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Bar
                  Container(width: 6, color: typeColor),

                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tags
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  activity.actType.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  statusText,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Title
                          Text(
                            activity.name,
                            style: GoogleFonts.kanit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isHistory
                                  ? Colors.grey.shade700
                                  : const Color(0xFF222222),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),

                          // Info
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                displayTime,
                                style: GoogleFonts.kanit(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.place,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  cleanLocation,
                                  style: GoogleFonts.kanit(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Progress
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.people_alt,
                                          size: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Registered: (${activity.currentParticipants}/${activity.maxParticipants})",
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        backgroundColor: Colors.grey.shade100,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              isHistory
                                                  ? Colors.grey
                                                  : const Color(0xFF4A80FF),
                                            ),
                                        minHeight: 4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Model Class
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
  final int isCompulsory;

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
    required this.isCompulsory,
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
      isCompulsory: json['isCompulsory'] ?? 0,
    );
  }
}
