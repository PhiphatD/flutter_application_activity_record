import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'participants_details_screen.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'enterprise_scanner_screen.dart';
import 'activities/activity_qr_display_screen.dart';
import '../../../widgets/organizer_header.dart';

class ActivitiesParticipantsListScreen extends StatefulWidget {
  const ActivitiesParticipantsListScreen({super.key});

  @override
  State<ActivitiesParticipantsListScreen> createState() =>
      _ActivitiesParticipantsListScreenState();
}

class _ActivitiesParticipantsListScreenState
    extends State<ActivitiesParticipantsListScreen>
    with SingleTickerProviderStateMixin {
  final String baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";
  WebSocketChannel? _channel;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  late TabController _tabController;

  bool _isLoading = true;
  List<_Activity> _activities = [];
  String _currentOrganizerName = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchActivities();
    _search.addListener(() => setState(() => _query = _search.text.trim()));
    _connectWebSocket();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _search.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  void _connectWebSocket() {
    try {
      final wsUrl = Uri.parse(
        'ws://numerably-nonevincive-kyong.ngrok-free.dev/ws',
      );
      _channel = WebSocketChannel.connect(wsUrl);

      _channel!.stream.listen((message) {
        // [UPDATED] เพิ่มเงื่อนไข REFRESH_ACTIVITIES
        if (message == "REFRESH_PARTICIPANTS" ||
            message == "REFRESH_ACTIVITIES" || // <--- เพิ่มตรงนี้
            message.toString().contains("CHECKIN_SUCCESS")) {
          print("⚡ List Update: $message");
          _fetchActivities(); // โหลดข้อมูลใหม่
        }
      });
    } catch (e) {
      print("WS Error: $e");
    }
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

  // --- [NEW LOGIC] Smart Scan Section ---
  List<_Activity> _getMyActivitiesToday() {
    final today = DateTime.now();
    return _activities.where((a) {
      if (a.organizerName != _currentOrganizerName) return false;
      if (a.status == 'Closed' || a.status == 'Cancelled') return false;
      final isToday =
          a.activityDate.year == today.year &&
          a.activityDate.month == today.month &&
          a.activityDate.day == today.day;
      return isToday;
    }).toList();
  }

  void _handleSmartScan() async {
    final activities = _getMyActivitiesToday();

    if (activities.isEmpty) {
      _showErrorDialog(
        "No Active Activities Today",
        "คุณไม่มีกิจกรรมที่จัดขึ้นในวันนี้ หรือกิจกรรมยังไม่เปิด",
      );
    } else if (activities.length == 1) {
      final act = activities.first;
      _openScanner(act.actId, act.name);
    } else {
      _showActivitySelectionSheet(activities);
    }
  }

  void _showActivitySelectionSheet(List<_Activity> activities) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Select Activity to Check-in",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...activities.map(
                (act) => ListTile(
                  leading: const Icon(Icons.event, color: Color(0xFF4A80FF)),
                  title: Text(act.name, style: GoogleFonts.kanit()),
                  subtitle: Text("${act.startTime} - ${act.endTime}"),
                  onTap: () {
                    Navigator.pop(context);
                    _openScanner(act.actId, act.name);
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _openScanner(String defaultActId, String actName) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EnterpriseScannerScreen()),
    );

    if (result != null) {
      String targetActId = defaultActId;
      String empId = result;

      if (result.contains("EMP:")) {
        empId = result.split("EMP:")[1].split("|")[0];
      } else if (result.contains("_REFRESH_")) {
        empId = result.split("_REFRESH_")[0];
      }

      _processCheckIn(empId, targetActId);
    }
  }

  Future<void> _processCheckIn(String empId, String actId) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Processing Check-in..."),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/checkin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'emp_id': empId,
          'act_id': actId,
          'scanned_by': 'organizer',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        _showResultDialog(
          true,
          "Check-in Success!",
          "${data['emp_name']}\nEarned +${data['points_earned']} pts",
        );
        _fetchActivities();
      } else {
        final err = jsonDecode(utf8.decode(response.bodyBytes));
        _showResultDialog(
          false,
          "Check-in Failed",
          err['detail'] ?? "Unknown Error",
        );
      }
    } catch (e) {
      _showResultDialog(false, "Error", "Connection failed");
    }
  }

  void _showResultDialog(bool success, String title, String msg) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              success ? Icons.check_circle : Icons.cancel,
              color: success ? Colors.green : Colors.red,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(c),
              style: ElevatedButton.styleFrom(
                backgroundColor: success ? Colors.green : Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String title, String msg) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(msg, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // --- End Scan Logic ---

  Map<DateTime, List<_Activity>> _getGroupedActivities(bool isHistory) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final filteredList = _activities.where((a) {
      if (a.organizerName != _currentOrganizerName) return false;

      final matchesSearch =
          _query.isEmpty || a.name.toLowerCase().contains(_query.toLowerCase());
      if (!matchesSearch) return false;

      final actDate = DateTime(
        a.activityDate.year,
        a.activityDate.month,
        a.activityDate.day,
      );

      if (!isHistory) {
        return !actDate.isBefore(today);
      } else {
        return actDate.isBefore(today);
      }
    }).toList();

    if (!isHistory) {
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
    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFFF5F7FA)),
          SafeArea(
            child: Column(
              children: [
                OrganizerHeader(
                  title: "Welcome Organizer",
                  subtitle: "Manage check-ins",
                  searchController: _search,
                  searchHint: "Search your activities...",
                  onScanSuccess: _handleSmartScan,
                ),
                _buildTabBar(),
                const Divider(height: 1, thickness: 1, color: Colors.black12),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildListContent(isHistory: false),
                            _buildListContent(isHistory: true),
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

  Widget _buildListContent({required bool isHistory}) {
    final groupedMap = _getGroupedActivities(isHistory);
    final dateKeys = groupedMap.keys.toList();

    // [FIX] ต้องครอบ RefreshIndicator แม้ในกรณี Empty State
    if (dateKeys.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchActivities,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: _buildEmptyState(),
          ),
        ),
      );
    }

    return RefreshIndicator(
      // [CHECK] ของเดิมมีแล้ว แต่เช็ค parameters
      onRefresh: _fetchActivities,
      color: const Color(0xFF4A80FF),
      child: ListView.builder(
        physics:
            const AlwaysScrollableScrollPhysics(), // [IMPORTANT] ต้องใส่เพื่อให้ลากได้ตลอด
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
      ),
    );
  }

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

  // [UPDATED] เพิ่มการเช็ค TODAY และการ์ดแบบใหม่
  Widget _buildActivityGroup({
    required DateTime date,
    required List<_Activity> cards,
    required bool isHistoryTab,
  }) {
    final relativeDate = _getRelativeDateString(date);
    final isToday = relativeDate == "Today"; // เช็คว่าเป็นวันนี้ไหม

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // [NEW] Badge TODAY
              if (isToday)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "TODAY",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Text(
                DateFormat('EEE, d MMM y', 'en_US').format(date),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isToday
                      ? Colors.black
                      : Colors.black87, // สีเข้มขึ้นถ้าเป็นวันนี้
                ),
              ),
              if (relativeDate.isNotEmpty && !isToday) ...[
                // ไม่โชว์ซ้ำถ้ามีป้าย TODAY แล้ว
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
                  // [NEW] ส่ง callback เปิด QR
                  onShowQr: () => _showEventQr(a),
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

  // [NEW] ฟังก์ชันเปิดหน้า QR
  void _showEventQr(_Activity a) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityQrDisplayScreen(
          activityName: a.name,
          actId: a.actId,
          qrData: "ACTION:CHECKIN|ACT_ID:${a.actId}",
          timeInfo: "${a.startTime} - ${a.endTime}",
        ),
      ),
    );
  }
}

// [UPDATED] ปรับดีไซน์การ์ดให้เหมาะกับการ Check Participant
class _ParticipantActivityCard extends StatelessWidget {
  final _Activity activity;
  final bool isHistory;
  final VoidCallback onTap;
  final VoidCallback onShowQr; // [NEW] รับ callback

  const _ParticipantActivityCard({
    required this.activity,
    required this.isHistory,
    required this.onTap,
    required this.onShowQr,
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

    // จัดการเวลา
    final displayTime = (activity.startTime == "-" || activity.endTime == "-")
        ? "Time TBA"
        : "${activity.startTime} - ${activity.endTime}";

    // จัดการสถานที่
    String cleanLocation = activity.location;
    if (cleanLocation.contains(" at :")) {
      cleanLocation = cleanLocation.split(" at :")[0].trim();
    }

    return Opacity(
      opacity: isHistory ? 0.7 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
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
                // 1. แถบสีด้านซ้าย
                Container(width: 6, color: typeColor),

                // 2. เนื้อหาหลัก (กดแล้วไปดูรายละเอียดคนเข้างาน)
                Expanded(
                  child: InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Badge Type
                          // Badge Type & Required Tag
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
                              if (activity.isCompulsory == 1) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.red.shade100,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.lock_outline,
                                        size: 10,
                                        color: Colors.red.shade700,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        "REQUIRED",
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),

                          // ชื่อกิจกรรม
                          Text(
                            activity.name,
                            style: GoogleFonts.kanit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isHistory
                                  ? Colors.grey.shade700
                                  : const Color(0xFF222222),
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),

                          // เวลาและสถานที่
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
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Progress Bar จำนวนคน
                          Row(
                            children: [
                              Icon(
                                Icons.group,
                                size: 14,
                                color: isHistory ? Colors.grey : Colors.blue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Registered: ${activity.currentParticipants}",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isHistory
                                      ? Colors.grey
                                      : Colors.blue.shade700,
                                ),
                              ),
                              if (activity.maxParticipants > 0)
                                Text(
                                  " / ${activity.maxParticipants}",
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. ปุ่ม QR Code ทางขวา (แยกส่วน)
                if (!isHistory) // ซ่อนถ้าจบไปแล้ว
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.grey.shade100),
                      ),
                    ),
                    child: InkWell(
                      onTap: onShowQr,
                      child: Container(
                        width: 80,
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.qr_code_2,
                                color: Colors.orange.shade700,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Event QR",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Model Class (เหมือนเดิม)
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
