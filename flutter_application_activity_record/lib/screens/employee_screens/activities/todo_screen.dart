import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'activity_detail_screen.dart';
import '../profile/profile_screen.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen>
    with SingleTickerProviderStateMixin {
  final String baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";
  bool _isLoading = true;
  List<_TodoActivity> _allActivities = []; // ข้อมูลดิบทั้งหมด
  late TabController _tabController;

  // --- Filter State ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  List<String> _selectedTypes = [];
  bool _showMandatoryOnly = false;
  // รายการ Type ที่มีให้เลือก (ควรดึงจาก DB จริงๆ แต่ Hardcode เพื่อ Demo ได้)
  final List<String> _availableTypes = [
    'Training',
    'Seminar',
    'Workshop',
    'Activity',
    'Expo',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    _fetchMyRegistrations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMyRegistrations() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String empId = prefs.getString('empId') ?? '';

      final response = await http.get(
        Uri.parse('$baseUrl/my-registrations/$empId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _allActivities = data
                .map((json) => _TodoActivity.fromJson(json))
                .toList();
            _isLoading = false;
          });
        }
      } else {
        throw Exception("Failed to load");
      }
    } catch (e) {
      print("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // [CORE LOGIC] ฟังก์ชันกรองข้อมูลหลัก
  List<_TodoActivity> _getFilteredList(String statusFilter) {
    return _allActivities.where((act) {
      // 1. Status Filter (Tab)
      bool statusMatch = false;
      if (statusFilter == 'History') {
        statusMatch = act.status == 'Joined';
      } else {
        statusMatch = act.status == statusFilter;
      }
      if (!statusMatch) return false;

      // 2. Search Query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchName = act.name.toLowerCase().contains(query);
        final matchLoc = act.location.toLowerCase().contains(query);
        if (!matchName && !matchLoc) return false;
      }

      // 3. Type Filter
      if (_selectedTypes.isNotEmpty) {
        // เช็คว่า type ของกิจกรรม อยู่ใน list ที่เลือกไหม (case insensitive)
        bool typeMatch = _selectedTypes.any(
          (t) => t.toLowerCase() == act.actType.toLowerCase(),
        );
        // เผื่อกรณีข้อมูลไม่ตรงเป๊ะ หรือ actType เป็นค่าอื่น
        if (!typeMatch) return false;
      }

      // 4. Mandatory Filter
      if (_showMandatoryOnly && !act.isCompulsory) {
        return false;
      }

      return true;
    }).toList();
  }

  // [UI] Filter Modal Bottom Sheet
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
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
                          // Reset Logic
                          setState(() {
                            _selectedTypes.clear();
                            _showMandatoryOnly = false;
                          });
                          setStateModal(() {});
                        },
                        child: Text(
                          "Reset",
                          style: GoogleFonts.poppins(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Mandatory Switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      "Show Mandatory Only",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      "Only show required activities",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    value: _showMandatoryOnly,
                    activeColor: const Color(0xFF4A80FF),
                    onChanged: (val) {
                      setState(() => _showMandatoryOnly = val);
                      setStateModal(() {});
                    },
                  ),
                  const Divider(),
                  const SizedBox(height: 10),

                  // Activity Types
                  Text(
                    "Activity Type",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableTypes.map((type) {
                      final isSelected = _selectedTypes.contains(type);
                      return FilterChip(
                        label: Text(type),
                        selected: isSelected,
                        selectedColor: const Color(0xFFE6EFFF),
                        checkmarkColor: const Color(0xFF4A80FF),
                        labelStyle: GoogleFonts.poppins(
                          color: isSelected
                              ? const Color(0xFF4A80FF)
                              : Colors.black87,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _selectedTypes.add(type);
                            } else {
                              _selectedTypes.remove(type);
                            }
                          });
                          setStateModal(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 30),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A80FF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Apply Filters",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isFilterActive = _selectedTypes.isNotEmpty || _showMandatoryOnly;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // [NEW] Search & Filter Bar Area
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search activities...',
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _showFilterModal,
                  child: Container(
                    height: 45,
                    width: 45,
                    decoration: BoxDecoration(
                      color: isFilterActive
                          ? const Color(0xFF4A80FF)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: isFilterActive ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),

          _buildTabBar(),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildGroupedList(
                        statusFilter: "Upcoming",
                        isTimeline: true,
                      ),
                      _buildGroupedList(
                        statusFilter: "Joined",
                        isTimeline: false,
                      ),
                      _buildGroupedList(
                        statusFilter: "Missed",
                        isTimeline: false,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: Text(
        'My Schedule',
        style: GoogleFonts.poppins(
          color: const Color(0xFF375987),
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFF0F0F0),
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=12'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4), // เงาลงล่างนิดหน่อยเพื่อให้แยกส่วน
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
          Tab(text: "Upcoming"),
          Tab(text: "History"),
          Tab(text: "Missed"),
        ],
      ),
    );
  }

  Widget _buildGroupedList({
    required String statusFilter,
    required bool isTimeline,
  }) {
    // [UPDATED] ใช้ฟังก์ชันกรองข้อมูลที่สร้างใหม่
    final filteredList = _getFilteredList(statusFilter);

    if (filteredList.isEmpty) return _buildEmptyState(statusFilter);

    // Group by Date
    Map<String, List<_TodoActivity>> grouped = {};
    for (var act in filteredList) {
      String dateKey = DateFormat('yyyy-MM-dd').format(act.activityDate);
      if (grouped[dateKey] == null) grouped[dateKey] = [];
      grouped[dateKey]!.add(act);
    }

    // Sort Keys
    var sortedKeys = grouped.keys.toList();
    if (statusFilter == 'Upcoming') {
      sortedKeys.sort((a, b) => a.compareTo(b));
    } else {
      sortedKeys.sort((a, b) => b.compareTo(a));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        String dateKey = sortedKeys[index];
        DateTime date = DateTime.parse(dateKey);
        List<_TodoActivity> acts = grouped[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateHeader(date, isTimeline),
            const SizedBox(height: 12),
            ...acts.map(
              (act) => isTimeline
                  ? _buildTimelineCard(act)
                  : _buildStandardCard(act, statusFilter),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  // ... (ส่วน UI Widget: _buildDateHeader, _buildTimelineCard, _buildStandardCard, _buildEmptyState Copy ของเดิมมาแปะได้เลยครับ)
  // เพื่อประหยัดพื้นที่ ผมจะละส่วน UI ที่ไม่ได้แก้ไว้ (ใช้ของเดิมจากคำตอบก่อนหน้าได้เลย)

  // [PASTE PREVIOUS UI WIDGETS HERE: _buildDateHeader, _buildTimelineCard, _buildStandardCard, _buildEmptyState, _goToDetail, _getTypeColor]
  // (หากคุณต้องการให้ผมแปะให้ครบทุกบรรทัด แจ้งได้เลยครับ แต่ Logic หลักๆ อยู่ด้านบนหมดแล้ว)

  Widget _buildDateHeader(DateTime date, bool isHighlightToday) {
    bool isToday = DateUtils.isSameDay(date, DateTime.now());
    return Row(
      children: [
        if (isToday && isHighlightToday)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              "TODAY",
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        Text(
          DateFormat('EEE, d MMMM y').format(date),
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineCard(_TodoActivity act) {
    bool isCompulsory = act.isCompulsory;
    Color typeColor = _getTypeColor(act.actType);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(width: 2, height: 16, color: Colors.grey[300]),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: isCompulsory ? Colors.orange.shade800 : typeColor,
                      width: 3,
                    ),
                  ),
                ),
                Expanded(child: Container(width: 2, color: Colors.grey[300])),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: GestureDetector(
                onTap: () => _goToDetail(act),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: isCompulsory
                        ? Border.all(color: Colors.orange.shade200, width: 1)
                        : Border.all(color: Colors.transparent),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 4,
                          decoration: BoxDecoration(
                            color: isCompulsory
                                ? Colors.orange.shade800
                                : typeColor,
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${act.startTime} - ${act.endTime}",
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                                if (isCompulsory)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.orange.shade100,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.lock,
                                          size: 10,
                                          color: Colors.orange.shade800,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "REQUIRED",
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.orange.shade800,
                                          ),
                                        ),
                                      ],
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
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 14,
                                        color: Colors.grey[500],
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          act.location,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF8E1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.amber.shade100,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        size: 14,
                                        color: Colors.amber.shade800,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${act.point} Pts",
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardCard(_TodoActivity act, String status) {
    bool isJoined = status == "Joined";
    Color statusColor = isJoined ? Colors.green : Colors.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GestureDetector(
        onTap: () => _goToDetail(act),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isJoined ? Icons.check_circle : Icons.cancel,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      act.name,
                      style: GoogleFonts.kanit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isJoined
                            ? const Color(0xFF1F2937)
                            : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('d MMM, HH:mm').format(
                        DateTime(
                          act.activityDate.year,
                          act.activityDate.month,
                          act.activityDate.day,
                        ).add(
                          Duration(
                            hours: int.parse(act.startTime.split(":")[0]),
                            minutes: int.parse(act.startTime.split(":")[1]),
                          ),
                        ),
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              if (isJoined)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "+${act.point}",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    Text(
                      "pts",
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Missed",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade400,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToDetail(_TodoActivity act) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityDetailScreen(activityId: act.actId),
      ),
    );
  }

  Widget _buildEmptyState(String status) {
    String message = "";
    IconData icon = Icons.event_note;

    if (status == "Upcoming") {
      message = "No upcoming tasks.\nEnjoy your free time! 🎉";
      icon = Icons.done_all_rounded;
    } else if (status == "Joined") {
      message = "No history yet.\nJoin activities to build your portfolio.";
      icon = Icons.history_toggle_off_rounded;
    } else {
      message = "Excellent!\nYou haven't missed any activity.";
      icon = Icons.check_circle_outline_rounded;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(icon, size: 50, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.grey[500],
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'training':
        return const Color(0xFF4A80FF);
      case 'seminar':
        return const Color(0xFFFF9F1C);
      case 'workshop':
        return const Color(0xFF2EC4B6);
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}

// [UPDATED MODEL]
class _TodoActivity {
  final String actId;
  final String name;
  final String location;
  final DateTime activityDate;
  final String startTime;
  final String endTime;
  final String status;
  final bool isCompulsory;
  final String actType;
  final int point;

  _TodoActivity({
    required this.actId,
    required this.name,
    required this.location,
    required this.activityDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.isCompulsory,
    required this.actType,
    required this.point,
  });

  factory _TodoActivity.fromJson(Map<String, dynamic> json) {
    DateTime date = DateTime.now();
    if (json['activityDate'] != null) {
      try {
        date = DateTime.parse(json['activityDate']);
      } catch (_) {}
    }
    return _TodoActivity(
      actId: json['actId']?.toString() ?? '',
      name: json['name'] ?? 'Unknown Activity',
      location: json['location'] ?? '-',
      activityDate: date,
      startTime: json['startTime'] ?? '00:00',
      endTime: json['endTime'] ?? '00:00',
      status: json['status'] ?? 'Upcoming',
      isCompulsory: json['isCompulsory'] == 1 || json['isCompulsory'] == true,
      actType: json['actType'] ?? 'Activity',
      point: json['point'] ?? 0,
    );
  }
}
