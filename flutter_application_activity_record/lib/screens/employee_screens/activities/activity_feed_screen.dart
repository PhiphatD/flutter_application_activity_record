import 'dart:convert';
import 'dart:math'; // [NEW] Import Math เพื่อหา min/max
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../profile/profile_screen.dart';
import 'activity_detail_screen.dart';
import '../widgets/activity_card.dart';
import '../../../models/activity_model.dart';

class ActivityFeedScreen extends StatefulWidget {
  final VoidCallback? onGoToTodo;

  const ActivityFeedScreen({super.key, this.onGoToTodo});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen>
    with SingleTickerProviderStateMixin {
  final String baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";
  bool _isLoading = true;

  List<Activity> _activities = [];
  late TabController _tabController;
  List<Activity> _myUpcomingActivities = [];

  // [FILTER STATE]
  final TextEditingController _searchController = TextEditingController();

  // Dynamic Data for Filters (คำนวณจากข้อมูลจริง)
  List<String> _availableTypes = [];
  double _minPoint = 0;
  double _maxPoint = 1000;

  // Selected Filters
  List<String> _selectedTypes = [];
  bool _filterAvailableOnly = false;
  RangeValues _pointRange = const RangeValues(0, 1000);
  DateTimeRange? _selectedDateRange; // [NEW] ตัวแปรเก็บช่วงวันที่

  // [NEW] Favorite State
  Set<String> _favoriteActivityIds = {};
  bool _showOnlyFavorites = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() => setState(() {}));
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String empId =
          prefs.getString('empId') ?? ''; // ดึง ID พนักงานที่ Login

      // 1. Fetch All Activities (สำหรับ List ด้านล่าง)
      // [UPDATED] ส่ง emp_id ไปกับ Request ด้วย
      final responseAll = await http.get(
        Uri.parse('$baseUrl/activities?mode=future&emp_id=$empId'),
      );

      // 2. [NEW] Fetch My Upcoming Activities (สำหรับ Ticket ด้านบน)
      final responseMy = await http.get(
        Uri.parse('$baseUrl/my-activities/$empId'),
      );

      // 3. [NEW] Fetch Favorites
      final responseFav = await http.get(
        Uri.parse('$baseUrl/favorites/$empId'),
      );

      if (responseAll.statusCode == 200) {
        final List<dynamic> dataAll = json.decode(
          utf8.decode(responseAll.bodyBytes),
        );

        // [NEW] Parse My Upcoming Data
        List<Activity> myUpcoming = [];
        if (responseMy.statusCode == 200) {
          final List<dynamic> dataMy = json.decode(
            utf8.decode(responseMy.bodyBytes),
          );
          myUpcoming = dataMy.map((json) => Activity.fromJson(json)).toList();
        }

        // [NEW] Parse Favorites
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

          // [NEW] 1. Extract Dynamic Metadata for Filters
          // ดึง Type ทั้งหมดที่มีอยู่จริง ไม่ซ้ำกัน
          final types = loaded.map((e) => e.actType).toSet().toList();
          types.sort();

          // หาคะแนนต่ำสุด-สูงสุด เพื่อตั้งสเกล Slider
          double minP = 0;
          double maxP = 1000;
          if (loaded.isNotEmpty) {
            final points = loaded.map((e) => e.point.toDouble()).toList();
            minP = points.reduce(min);
            maxP = points.reduce(max);
            // เผื่อกรณี min=max หรือไม่มีข้อมูล ให้มี gap หน่อย
            if (minP == maxP) maxP += 100;
          }

          setState(() {
            _activities = loaded; // เก็บข้อมูลดิบไว้ก่อน

            // Update Filter Options
            _availableTypes = types;
            _minPoint = minP;
            _maxPoint = maxP;
            // Reset slider to full range initially
            _pointRange = RangeValues(minP, maxP);

            // [UPDATED] ใช้ข้อมูลจริงจาก API แทน Mock
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

  // [NEW] Function to Toggle Favorite
  Future<void> _toggleFavorite(String actId) async {
    // 1. Optimistic Update (เปลี่ยน UI ทันทีให้ลื่น)
    setState(() {
      if (_favoriteActivityIds.contains(actId)) {
        _favoriteActivityIds.remove(actId);
      } else {
        _favoriteActivityIds.add(actId);
      }
    });

    // 2. Call API Background
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
      // ถ้า Error อาจจะ Revert state คืน (Optional)
    }
  }

  // [SMART FILTER LOGIC]
  List<Activity> _applyFilters(List<Activity> source, String tabFilter) {
    return source.where((act) {
      // 1. Tab Filter
      if (tabFilter == 'Compulsory' && !act.isCompulsory) return false;
      if (tabFilter == 'New') {
        // Logic สำหรับ New อาจจะเป็น created_at หรือ เป็นกิจกรรมในอนาคต
        // ในที่นี้ขอใช้ logic ง่ายๆ คือ แสดงทั้งหมดไปก่อน หรือจะ limit 5 อันแรกใน UI
      }

      // [NEW] Filter Favorite
      if (_showOnlyFavorites && !_favoriteActivityIds.contains(act.actId)) {
        return false;
      }

      // 2. Search Text
      final query = _searchController.text.toLowerCase();
      if (query.isNotEmpty) {
        final match =
            act.name.toLowerCase().contains(query) ||
            act.location.toLowerCase().contains(query);
        if (!match) return false;
      }

      // 3. Type Filter
      if (_selectedTypes.isNotEmpty && !_selectedTypes.contains(act.actType)) {
        return false;
      }

      // 4. Availability
      if (_filterAvailableOnly) {
        if (act.maxParticipants > 0 &&
            act.currentParticipants >= act.maxParticipants) {
          return false;
        }
      }

      // 5. Point Range (Dynamic)
      if (act.point < _pointRange.start || act.point > _pointRange.end) {
        return false;
      }

      // 6. [NEW] Date Range Filter
      if (_selectedDateRange != null) {
        // เช็คว่าวันที่กิจกรรม อยู่ในช่วงที่เลือกไหม
        // ใช้ isBefore / isAfter ต้องระวังเรื่องเวลา เลยตัดเวลาทิ้งก่อนเทียบ
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

  // [NEW UI] Smart Filter Modal
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            // เช็คว่ามีการเลือกวันที่ไหม
            String dateText = "Any Date";
            if (_selectedDateRange != null) {
              final start = DateFormat(
                'd MMM',
              ).format(_selectedDateRange!.start);
              final end = DateFormat('d MMM').format(_selectedDateRange!.end);
              dateText = "$start - $end";
            }

            return SafeArea(
              child: Container(
                padding: const EdgeInsets.all(24),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Header ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Filter Activities",
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              // Reset Logic
                              setState(() {
                                _selectedTypes.clear();
                                _filterAvailableOnly = false;
                                _pointRange = RangeValues(_minPoint, _maxPoint);
                                _selectedDateRange = null;
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
                      const SizedBox(height: 24),

                      // --- 1. Date Filter (New) ---
                      Text(
                        "Date",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                            initialDateRange: _selectedDateRange,
                            builder: (context, child) {
                              return Theme(
                                data: ThemeData.light().copyWith(
                                  primaryColor: const Color(0xFF4A80FF),
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFF4A80FF),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setStateModal(() => _selectedDateRange = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 20,
                                color: Color(0xFF4A80FF),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                dateText,
                                style: GoogleFonts.poppins(
                                  color: _selectedDateRange != null
                                      ? Colors.black
                                      : Colors.grey,
                                  fontWeight: _selectedDateRange != null
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              const Spacer(),
                              if (_selectedDateRange != null)
                                GestureDetector(
                                  onTap: () => setStateModal(
                                    () => _selectedDateRange = null,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // --- 2. Type Filter (Dynamic) ---
                      Text(
                        "Activity Type",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      // ถ้า Type เยอะมาก ใช้ Container จำกัดความสูงแล้ว Scroll
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
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
                                      : Colors.grey[700],
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                onSelected: (val) {
                                  setStateModal(() {
                                    if (val)
                                      _selectedTypes.add(type);
                                    else
                                      _selectedTypes.remove(type);
                                  });
                                },
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: isSelected
                                        ? const Color(0xFF4A80FF)
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                showCheckmark: false,
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // --- 3. Points Range (Dynamic) ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Points Range",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "${_pointRange.start.toInt()} - ${_pointRange.end.toInt()} pts",
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF4A80FF),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      RangeSlider(
                        values: _pointRange,
                        min: _minPoint, // ใช้ค่า Min จาก DB
                        max: _maxPoint, // ใช้ค่า Max จาก DB
                        divisions: (_maxPoint - _minPoint) > 0
                            ? 20
                            : 1, // ป้องกันหาร 0
                        activeColor: const Color(0xFF4A80FF),
                        inactiveColor: Colors.grey.shade200,
                        labels: RangeLabels(
                          _pointRange.start.round().toString(),
                          _pointRange.end.round().toString(),
                        ),
                        onChanged: (RangeValues values) {
                          setStateModal(() => _pointRange = values);
                        },
                      ),

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 10),

                      // --- 4. Availability ---
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          "Available Only",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          "Hide fully booked activities",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        value: _filterAvailableOnly,
                        activeColor: const Color(0xFF4A80FF),
                        onChanged: (val) {
                          setStateModal(() => _filterAvailableOnly = val);
                        },
                      ),

                      const SizedBox(height: 30),

                      // Apply Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {}); // Trigger rebuild
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A80FF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            "Show Results",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // เช็คว่ามี Filter Active อยู่ไหม
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
        // [STEP 1] ใช้ Column หลักเพื่อแบ่งส่วน Fixed และ Scroll
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // --- ส่วนที่ 1: Fixed Header (ไม่เลื่อน) ---
                  _buildFixedHeader(),
                  _buildSearchBar(hasFilter),

                  // --- ส่วนที่ 2: Scrollable Area (เลื่อนได้) ---
                  Expanded(
                    child: NestedScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      headerSliverBuilder: (context, innerBoxIsScrolled) {
                        return [
                          // 2.1 Upcoming: เลื่อนหายไปได้
                          SliverToBoxAdapter(child: _buildMyUpcomingSection()),

                          // 2.2 TabBar: เลื่อนแล้วติดหนึบ (Sticky)
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _SliverTabBarDelegate(_buildTabBar()),
                          ),
                        ];
                      },
                      // 2.3 List รายการกิจกรรม
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

  Widget _buildActivityList({required String filter}) {
    // 1. Copy List มาเพื่อไม่ให้กระทบตัวแปรหลัก
    List<Activity> displayList = List.from(_activities);

    // 2. Apply Smart Filter (Search, Type, etc.)
    displayList = _applyFilters(displayList, filter);

    // 3. [NEW] Sorting Logic ตาม Tab
    if (filter == 'New') {
      // Strategy: "Newest Published First"
      // เนื่องจากเราไม่มี created_at เราจะใช้ actId เปรียบเทียบ (สมมติว่า ID มาก = ใหม่กว่า)
      // หรือถ้าอยากได้แบบ "งานที่เพิ่งประกาศ แต่จัดเดือนหน้า" ก็ควรเรียงตาม ID
      displayList.sort((a, b) => b.actId.compareTo(a.actId));

      // Limit: เอาแค่ 5 อันดับแรก
      if (displayList.length > 5) {
        displayList = displayList.sublist(0, 5);
      }
    } else if (filter == 'Compulsory') {
      // Strategy: "Soonest First" (เหมือน All) แต่กรองเฉพาะงานบังคับ
      displayList = displayList.where((a) => a.isCompulsory).toList();
      displayList.sort((a, b) => a.activityDate.compareTo(b.activityDate));
    } else {
      // Tab "All" (Default)
      // Strategy: "Soonest First" (ใกล้วันจัดที่สุด ขึ้นก่อน)
      displayList.sort((a, b) => a.activityDate.compareTo(b.activityDate));
    }

    if (displayList.isEmpty) return _buildEmptyState();

    // Grouping Logic (เหมือนเดิม)
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

  // ... (ส่วนประกอบ UI อื่นๆ คงเดิม: SearchBar, AppBar, Ticket, Group, EmptyState) ...
  // ท่านสามารถ Copy Widget เหล่านั้นจากไฟล์เดิมมาวางต่อท้ายตรงนี้ได้เลยครับ
  // เพื่อความกระชับ ผมขอละไว้ในฐานที่เข้าใจ (หรือถ้าต้องการให้รวมให้หมด บอกได้ครับ)

  // Copy: _buildSliverAppBar, _buildMyUpcomingSection, _buildTicketCard, _buildSearchBar, _buildTabBar, _buildEmptyState, _buildActivityGroup

  // ------------------------------------------------------
  // [PLACEHOLDERS FOR MISSING WIDGETS - REPLACE WITH ORIGINAL CODE]
  // [NEW] แปลงจาก SliverAppBar เป็น Widget ธรรมดาเพื่อให้ Fixed ได้
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
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=32'),
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
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: Colors.black54,
            ),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // [IMPROVED] Widget My Upcoming Section
  Widget _buildMyUpcomingSection() {
    // ถ้าไม่มี Upcoming ให้แสดง Widget เชิญชวนแทนการซ่อน
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
            height: 150, // ความสูง Ticket
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

  // ตัวแปรเก็บ ID (ต้องดึงมาจาก Prefs ใน init)
  String _currentEmpId = "";

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
          // [NEW] Favorite Filter Button
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

  // [NEW DESIGN] Ticket Card Widget (Boarding Pass Style)
  Widget _buildTicketCard(Activity act) {
    // ใช้ LayoutBuilder เพื่อให้ Responsive ตามความกว้างของ Container แม่
    return Container(
      width: 320, // ความกว้างมาตรฐานของ Ticket
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
              // --- LEFT PART: Event Info (75%) ---
              Expanded(
                flex: 3,
                child: Material(
                  color: Colors.white,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ActivityDetailScreen(activityId: act.actId),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: Color(0xFFEEEEEE),
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top Row: Type Badge & Time
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
                              // Status Text
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

                          // Title
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

                          // Date & Location Row
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

              // --- RIGHT PART: Action Stub (25%) ---
              // ส่วน "ฉีก" ของตั๋ว (กดเพื่อดู QR Ticket)
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
                        Text(
                          "Tap to show",
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 10,
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

  // [ENTERPRISE TICKET MODAL]
  void _showTicketQrModal(Activity act) {
    // สร้าง QR Data String
    final qrString =
        "ACTION:CHECKIN|SESSION:${act.sessionId}|EMP:$_currentEmpId";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // เปิดเพื่อให้เราคุมความสูงเองได้
      backgroundColor: Colors.transparent, // พื้นหลังใสเพื่อให้เห็นมุมโค้งสวยๆ
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            // [CRITICAL] ป้องกัน Home Indicator บัง
            top: false, // ไม่ต้องกันข้างบน เดี๋ยว Header มันจัดการเอง
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                24,
                12,
                24,
                12,
              ), // Padding รอบๆ
              child: Column(
                mainAxisSize: MainAxisSize
                    .min, // [FIX] ความสูงเท่าเนื้อหา ไม่เต็มจอ ไม่เลื่อน
                children: [
                  // 1. Drag Handle (ตัวขีดเล็กๆ ข้างบน)
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // 2. Header: Title
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

                  // 3. QR Code (Fixed Size, No Scroll)
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
                    child: Column(
                      children: [
                        QrImageView(
                          data: qrString,
                          version: QrVersions.auto,
                          size: 220.0, // [FIX] กำหนดขนาดตายตัว
                          gapless: false,
                          // embeddedImage: const NetworkImage('...'), // ใส่โลโก้ตรงกลางได้ถ้าต้องการ
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Scan to check-in",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. Time Info
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time_filled,
                          color: Color(0xFF4A80FF),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${DateFormat('d MMM y').format(act.activityDate)} • ${act.startTime}",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 5. Close Button (Primary Action)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFFF3F4F6,
                        ), // สีเทาอ่อน (Secondary Action)
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

                  // [FIX] เพิ่มระยะห่างด้านล่างอีกนิดเผื่อจอโค้ง
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: relativeDate == "Today"
                        ? Colors.green.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    relativeDate,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: relativeDate == "Today"
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        ...cards.map(
          (act) => ActivityCard(
            id: act.actId,
            type: act.actType,
            title: act.name,
            location: act.location,
            organizer: act.organizerName,
            points: act.point,
            currentParticipants: act.currentParticipants,
            maxParticipants: act.maxParticipants,
            isCompulsory: act.isCompulsory,
            status: act.status,
            isFavorite: _favoriteActivityIds.contains(act.actId), // [NEW]
            onToggleFavorite: () => _toggleFavorite(act.actId), // [NEW]
          ),
        ),
      ],
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

// [NEW Helper Class] สำหรับทำให้ TabBar ติดหนึบ
// [NEW Helper Class] สำหรับทำให้ TabBar ติดหนึบ
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
