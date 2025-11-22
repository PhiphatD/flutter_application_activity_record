import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_application_activity_record/screens/employee_screens/scan/employee_scanner_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../profile/profile_screen.dart';
import 'activity_detail_screen.dart';
import '../widgets/activity_card.dart';

import '../../../models/activity_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ActivityFeedScreen extends StatefulWidget {
  final VoidCallback? onGoToTodo;

  const ActivityFeedScreen({super.key, this.onGoToTodo});

  @override
  State<ActivityFeedScreen> createState() => ActivityFeedScreenState();
}

class ActivityFeedScreenState extends State<ActivityFeedScreen>
    with SingleTickerProviderStateMixin {
  final String baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";
  bool _isLoading = true;

  List<Activity> _activities = [];
  late TabController _tabController;
  List<Activity> _myUpcomingActivities = [];

  // [FILTER STATE]
  final TextEditingController _searchController = TextEditingController();

  List<String> _availableTypes = [];
  double _minPoint = 0;
  double _maxPoint = 1000;

  List<String> _selectedTypes = [];
  bool _filterAvailableOnly = false;
  RangeValues _pointRange = const RangeValues(0, 1000);
  DateTimeRange? _selectedDateRange;

  Set<String> _favoriteActivityIds = {};
  bool _showOnlyFavorites = false;

  WebSocketChannel? _channel;
  String _currentEmpId = ""; // เก็บ ID พนักงานไว้ใช้สร้าง QR

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() => setState(() {}));
    refreshData();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  void _connectWebSocket() {
    try {
      final wsUrl = Uri.parse(
        'ws://numerably-nonevincive-kyong.ngrok-free.dev/ws',
      );
      _channel = WebSocketChannel.connect(wsUrl);

      _channel!.stream.listen(
        (message) {
          print("⚡ Feed Update: $message");
          if (message == "REFRESH_ACTIVITIES" ||
              message == "REFRESH_PARTICIPANTS") {
            refreshData();
          }
        },
        onError: (error) => print("WS Error: $error"),
        onDone: () => print("WS Connection Closed"),
      );
    } catch (e) {
      print("WS Connection Failed: $e");
    }
  }

  Future<void> refreshData() async {
    // ไม่ต้อง Set Loading ทุกครั้ง เพื่อความลื่นไหล (Realtime feel)
    if (_activities.isEmpty) setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final String empId = prefs.getString('empId') ?? '';

      final responseAll = await http.get(
        Uri.parse('$baseUrl/activities?mode=future&emp_id=$empId'),
      );
      final responseMy = await http.get(
        Uri.parse('$baseUrl/my-activities/$empId'),
      );
      final responseFav = await http.get(
        Uri.parse('$baseUrl/favorites/$empId'),
      );

      if (responseAll.statusCode == 200) {
        final List<dynamic> dataAll = json.decode(
          utf8.decode(responseAll.bodyBytes),
        );

        List<Activity> myUpcoming = [];
        if (responseMy.statusCode == 200) {
          final List<dynamic> dataMy = json.decode(
            utf8.decode(responseMy.bodyBytes),
          );
          myUpcoming = dataMy.map((json) => Activity.fromJson(json)).toList();
        }

        Set<String> favs = {};
        if (responseFav.statusCode == 200) {
          final List<dynamic> favList = json.decode(
            utf8.decode(responseFav.bodyBytes),
          );
          favs = favList.map((e) => e.toString()).toSet();
        }

        if (mounted) {
          final loaded = dataAll
              .map((json) => Activity.fromJson(json))
              .toList();

          final types = loaded.map((e) => e.actType).toSet().toList();
          types.sort();

          double minP = 0;
          double maxP = 1000;
          if (loaded.isNotEmpty) {
            final points = loaded.map((e) => e.point.toDouble()).toList();
            minP = points.reduce(min);
            maxP = points.reduce(max);
            if (minP == maxP) maxP += 100;
          }

          setState(() {
            _activities = loaded;
            _availableTypes = types;
            _minPoint = minP;
            _maxPoint = maxP;
            _pointRange = RangeValues(minP, maxP);
            _myUpcomingActivities = myUpcoming;
            _favoriteActivityIds = favs;
            _currentEmpId = empId;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite(String actId) async {
    setState(() {
      if (_favoriteActivityIds.contains(actId)) {
        _favoriteActivityIds.remove(actId);
      } else {
        _favoriteActivityIds.add(actId);
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String empId = prefs.getString('empId') ?? '';
      await http.post(
        Uri.parse('$baseUrl/favorites/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'emp_id': empId, 'act_id': actId}),
      );
    } catch (e) {
      print("Error toggling favorite: $e");
    }
  }

  List<Activity> _applyFilters(List<Activity> source, String tabFilter) {
    return source.where((act) {
      // Tab Filter
      if (tabFilter == 'Compulsory' && !act.isCompulsory) return false;
      // Note: Tab 'New' logic is handled by sorting later

      // Favorite Filter
      if (_showOnlyFavorites && !_favoriteActivityIds.contains(act.actId)) {
        return false;
      }

      // Search Text
      final query = _searchController.text.toLowerCase();
      if (query.isNotEmpty) {
        final match =
            act.name.toLowerCase().contains(query) ||
            act.location.toLowerCase().contains(query);
        if (!match) return false;
      }

      // Type Filter
      if (_selectedTypes.isNotEmpty && !_selectedTypes.contains(act.actType)) {
        return false;
      }

      // Availability
      if (_filterAvailableOnly) {
        if (act.maxParticipants > 0 &&
            act.currentParticipants >= act.maxParticipants) {
          return false;
        }
      }

      // Point Range
      if (act.point < _pointRange.start || act.point > _pointRange.end) {
        return false;
      }

      // Date Range
      if (_selectedDateRange != null) {
        final actDate = DateUtils.dateOnly(act.activityDate);
        final start = DateUtils.dateOnly(_selectedDateRange!.start);
        final end = DateUtils.dateOnly(_selectedDateRange!.end);
        if (actDate.isBefore(start) || actDate.isAfter(end)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    bool isPointChanged =
        _pointRange.start > _minPoint || _pointRange.end < _maxPoint;
    final hasFilter =
        _selectedTypes.isNotEmpty ||
        _filterAvailableOnly ||
        isPointChanged ||
        _selectedDateRange != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildFixedHeader(),
                  _buildSearchBar(hasFilter),
                  Expanded(
                    child: NestedScrollView(
                      headerSliverBuilder: (context, innerBoxIsScrolled) {
                        return [
                          SliverToBoxAdapter(child: _buildMyUpcomingSection()),
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _SliverTabBarDelegate(_buildTabBar()),
                          ),
                        ];
                      },
                      body: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildActivityList(filter: 'All'),
                          _buildActivityList(filter: 'Compulsory'),
                          _buildActivityList(filter: 'New'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ... (ฟังก์ชัน _buildFixedHeader, _buildSearchBar, _showFilterModal เหมือนเดิม) ...
  // เพื่อความกระชับ ผมขอละไว้ ให้ใช้ของเดิมในไฟล์ที่คุณส่งมาได้เลยครับ
  // แต่ต้อง "เพิ่ม" ฟังก์ชัน _buildTicketCard ด้านล่างนี้ครับ

  // [ADDED] ฟังก์ชันที่หายไป
  Widget _buildTicketCard(Activity act) {
    return Container(
      width: 320,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- LEFT PART: Event Info ---
              Expanded(
                flex: 3,
                child: Material(
                  color: Colors.white,
                  child: InkWell(
                    // [DOUBLE SAFETY] กดแล้วรอ แล้วโหลดใหม่
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ActivityDetailScreen(activityId: act.actId),
                        ),
                      );
                      refreshData();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Color(0xFFEEEEEE), width: 2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6EFFF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  act.actType.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF4A80FF),
                                  ),
                                ),
                              ),
                              Text(
                                "Upcoming",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            act.name,
                            style: GoogleFonts.kanit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1F2937),
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "${DateFormat('d MMM').format(act.activityDate)}, ${act.startTime}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      act.location,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // --- RIGHT PART: Action Stub ---
              Material(
                color: const Color(0xFF4A80FF),
                child: InkWell(
                  onTap: () => _showTicketQrModal(act),
                  child: SizedBox(
                    width: 90,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.qr_code_2,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Ticket",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
    );
  }

  void _showTicketQrModal(Activity act) {
    final qrString =
        "ACTION:CHECKIN|SESSION:${act.sessionId}|EMP:$_currentEmpId";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    "Activity Ticket",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    act.name,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.kanit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: qrString,
                      version: QrVersions.auto,
                      size: 220.0,
                      gapless: false,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F4F6),
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Close",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // [UPDATED] ฟังก์ชันสร้างรายการกิจกรรม (เพิ่ม Double Safety)
  Widget _buildActivityList({required String filter}) {
    List<Activity> displayList = List.from(_activities);
    displayList = _applyFilters(displayList, filter);

    if (filter == 'New') {
      displayList.sort((a, b) => b.actId.compareTo(a.actId));
      if (displayList.length > 5) displayList = displayList.sublist(0, 5);
    } else if (filter == 'Compulsory') {
      displayList = displayList.where((a) => a.isCompulsory).toList();
      displayList.sort((a, b) => a.activityDate.compareTo(b.activityDate));
    } else {
      displayList.sort((a, b) => a.activityDate.compareTo(b.activityDate));
    }

    if (displayList.isEmpty) return _buildEmptyState();

    Map<DateTime, List<Activity>> grouped = {};
    for (var act in displayList) {
      final dateKey = DateTime(
        act.activityDate.year,
        act.activityDate.month,
        act.activityDate.day,
      );
      if (grouped[dateKey] == null) grouped[dateKey] = [];
      grouped[dateKey]!.add(act);
    }
    final sortedDates = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        return _buildActivityGroup(
          activityDate: formatActivityDate(date),
          relativeDate: getRelativeDateString(date),
          cards: grouped[date]!,
        );
      },
    );
  }

  // [UPDATED] ส่ง onTap ไปให้ ActivityCard
  Widget _buildActivityGroup({
    required String activityDate,
    required String relativeDate,
    required List<Activity> cards,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24.0, bottom: 12.0, left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                activityDate,
                style: GoogleFonts.kanit(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(width: 12),
              if (relativeDate.isNotEmpty)
                Text(
                  relativeDate,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ),
        ...cards.map((act) {
          String cardStatus = act.status;
          if (act.isRegistered) cardStatus = 'Joined';

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: ActivityCard(
              id: act.actId,
              type: act.actType,
              title: act.name,
              location: act.location,
              organizer: act.organizerName,
              points: act.point,
              currentParticipants: act.currentParticipants,
              maxParticipants: act.maxParticipants,
              isCompulsory: act.isCompulsory,
              status: cardStatus,
              isFavorite: _favoriteActivityIds.contains(act.actId),
              onToggleFavorite: () => _toggleFavorite(act.actId),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ActivityDetailScreen(activityId: act.actId),
                  ),
                );
                refreshData();
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFixedHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: const CircleAvatar(
              backgroundImage: CachedNetworkImageProvider(
                'https://i.pravatar.cc/150?img=32',
              ),
              radius: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hello, Employee!",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                "Let's join activities",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF375987),
                ),
              ),
            ],
          ),
          const Spacer(),

          // [NEW] ย้ายปุ่ม Scan มาไว้ตรงนี้ (ข้างกระดิ่ง)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(
                Icons.qr_code_scanner,
                color: Color(0xFF4A80FF),
              ), // ใช้สี Theme
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmployeeScannerScreen(),
                  ),
                );
                if (result == true) {
                  refreshData(); // เรียกฟังก์ชันของตัวเองได้เลย
                }
              },
            ),
          ),

          const SizedBox(width: 12), // เว้นระยะห่าง
          // ปุ่ม Notification เดิม
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(
                Icons.notifications_outlined,
                color: Colors.black54,
              ),
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyUpcomingSection() {
    if (_myUpcomingActivities.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.event_available, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              "No upcoming activities",
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
            Text(
              "Register now to join!",
              style: GoogleFonts.poppins(
                color: const Color(0xFF4A80FF),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Upcoming",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                if (_myUpcomingActivities.length > 2)
                  GestureDetector(
                    onTap: widget.onGoToTodo,
                    child: Text(
                      "See all",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF4A80FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 150,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _myUpcomingActivities.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final act = _myUpcomingActivities[index];
                return _buildTicketCard(act);
              },
            ),
          ),
        ],
      ),
    );
  }

  TabBar _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: const Color(0xFF4A80FF),
      unselectedLabelColor: Colors.grey,
      indicatorColor: const Color(0xFF4A80FF),
      indicatorWeight: 3,
      labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      unselectedLabelStyle: GoogleFonts.poppins(),
      tabs: const [
        Tab(text: "All"),
        Tab(text: "Compulsory"),
        Tab(text: "New"),
      ],
    );
  }

  Widget _buildSearchBar(bool hasFilter) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        children: [
          Expanded(
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              setState(() {
                _showOnlyFavorites = !_showOnlyFavorites;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _showOnlyFavorites ? Colors.red.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: _showOnlyFavorites
                    ? Border.all(color: Colors.red.shade200)
                    : null,
              ),
              child: Icon(
                _showOnlyFavorites ? Icons.favorite : Icons.favorite_border,
                color: _showOnlyFavorites ? Colors.red : Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _showFilterModal,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasFilter ? const Color(0xFF4A80FF) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.tune_rounded,
                color: hasFilter ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ... (Copy _showFilterModal, _buildEmptyState, Helpers เดิมมาใส่ตรงนี้) ...
  // หรือถ้าคุณมีไฟล์เดิมอยู่แล้ว แค่แก้ _buildActivityGroup และเพิ่ม _buildTicketCard ก็พอครับ
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.all(24),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Filter Activities",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedTypes.clear();
                                _filterAvailableOnly = false;
                                _pointRange = RangeValues(_minPoint, _maxPoint);
                                _selectedDateRange = null;
                              });
                              Navigator.pop(context);
                            },
                            child: Text(
                              "Reset",
                              style: GoogleFonts.poppins(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Type",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableTypes.map((type) {
                          final isSelected = _selectedTypes.contains(type);
                          return FilterChip(
                            label: Text(type),
                            selected: isSelected,
                            selectedColor: const Color(0xFFFFF6CC),
                            checkmarkColor: Colors.orange.shade900,
                            labelStyle: GoogleFonts.poppins(
                              color: isSelected
                                  ? Colors.orange.shade900
                                  : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            onSelected: (bool selected) {
                              setStateModal(() {
                                if (selected)
                                  _selectedTypes.add(type);
                                else
                                  _selectedTypes.remove(type);
                              });
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
                      // ... (ส่วนอื่นๆ ของ Filter Modal เหมือนเดิม) ...
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No activities found",
            style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// --- Helpers ---
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
  if (differenceInDays < 0) return "Past Event";
  if (differenceInDays == 0) return "Today";
  if (differenceInDays == 1) return "Tomorrow";
  if (differenceInDays <= 7) return "This Week";
  if (differenceInDays <= 30) return "This Month";
  return "";
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white, // สีพื้นหลัง TabBar
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
