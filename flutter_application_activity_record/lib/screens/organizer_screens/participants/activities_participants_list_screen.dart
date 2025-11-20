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
    extends State<ActivitiesParticipantsListScreen> {
  final String baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";

  final TextEditingController _search = TextEditingController();
  String _query = '';
  int _selectedTab = 0; // 0=Active, 1=History
  bool _isLoading = true;
  List<_Activity> _activities = [];
  String _currentOrganizerName = "";

  // ตัวแปรเก็บค่า Filter ที่เลือก
  List<String> _selectedTypes = [];
  String? _selectedStatus;
  List<String> _availableTypes = []; // ดึงจาก DB

  int _filterCompulsoryIndex = 0; // 0=All, 1=Compulsory, 2=Optional
  bool _filterOnlyAvailable = false; // true = ซ่อนงานที่เต็มแล้ว

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
        final loadedActivities = data
            .map((json) => _Activity.fromJson(json))
            .toList();
        // [NEW] ดึง Type ทั้งหมดที่มีในระบบมาทำเป็นตัวเลือก Filter (Unique values)
        final types = loadedActivities.map((a) => a.actType).toSet().toList();
        if (mounted) {
          setState(() {
            _activities = data.map((json) => _Activity.fromJson(json)).toList();
            _availableTypes = types;
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

      // 3. [NEW] Filter Type
      if (_selectedTypes.isNotEmpty && !_selectedTypes.contains(a.actType)) {
        return false;
      }

      // 4. [NEW] Filter Status
      if (_selectedStatus != null && a.status != _selectedStatus) {
        return false;
      }

      // 5. [NEW] Filter Compulsory
      if (_filterCompulsoryIndex == 1 && a.isCompulsory == 0) return false;
      if (_filterCompulsoryIndex == 2 && a.isCompulsory == 1) return false;

      // 6. [NEW] Filter Availability (Hide Full)
      if (_filterOnlyAvailable) {
        if (a.maxParticipants > 0 &&
            a.currentParticipants >= a.maxParticipants) {
          return false;
        }
      }

      // 7. Filter Date (Tab)
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
      // [1] ลบ backgroundColor เดิมออก (หรือ comment ไว้) เพราะเราจะใช้ Gradient ทับ
      // backgroundColor: organizerBg,
      body: Stack(
        // [2] ใช้ Stack เพื่อซ้อน Layer
        children: [
          _buildBackground(), // [3] วางพื้นหลังไว้ล่างสุด
          // เนื้อหาหลัก
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                _buildTabs(),

                // [4] ปรับสีเส้นคั่นให้จางลงเล็กน้อยเพื่อให้เข้ากับพื้นหลังใหม่
                const Divider(height: 1, thickness: 1, color: Colors.black12),

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
                            bottom:
                                80.0 + MediaQuery.of(context).padding.bottom,
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
        ],
      ),
    );
  }

  // [5] เพิ่มฟังก์ชันสร้างพื้นหลัง
  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          // สีเหลืองอ่อนไล่ลงมาเป็นสีขาว (Theme Organizer)
          colors: [Color(0xFFFFF6CC), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.4], // ไล่สีถึงประมาณ 40% ของจอ
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

    // --- Future (Active Tab) ---
    if (differenceInDays == 0) return "Today";
    if (differenceInDays == 1) return "Tomorrow";
    if (differenceInDays > 1 && differenceInDays <= 7) return "This Week";
    if (differenceInDays > 7 && differenceInDays <= 30) return "This Month";
    if (differenceInDays > 30) return "Upcoming";

    // --- Past (History Tab) ---
    if (differenceInDays < 0) {
      final daysAgo = differenceInDays.abs();
      if (daysAgo == 1)
        return "Yesterday"; // เพิ่ม Yesterday ให้ดูใส่ใจรายละเอียด
      if (daysAgo <= 7) return "Last Week";
      if (daysAgo <= 30) return "Last Month"; // เพิ่ม Last Month
      return "Past Event"; // เก็บตกรายการที่เก่ากว่า 1 เดือน
    }
    return "";
  }

  // [UPDATED] 4. อัปเดต List เพื่อซ่อนปุ่ม Scan
  Widget _buildActivityGroup({
    required DateTime date,
    required List<_Activity> cards,
  }) {
    final relativeDate = _getRelativeDateString(date);
    // เช็คว่าตอนนี้อยู่ Tab History หรือไม่
    final isHistory = _selectedTab == 1;

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
                  onTap: () => _navigateToDetail(a, isHistory),
                  onScan: isHistory ? null : () => _scanQrDirectly(a),
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
          // [เพิ่ม 3 บรรทัดนี้ครับ] ส่งข้อมูลเวลาและสถานะบังคับไปด้วย
          startTime: a.startTime,
          endTime: a.endTime,
          isCompulsory: a.isCompulsory,
        ),
      ),
    );
  }

  // 1. เปิด Scanner (Mode A: สแกนพนักงาน)
  void _scanQrDirectly(_Activity activity) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EnterpriseScannerScreen(),
      ), // ใช้หน้าจอใหม่
    );

    if (result != null) {
      if (result == "SHOW_ACTIVITY_QR") {
        // Organizer อยากเปิด QR กิจกรรมแทน (Mode B)
        _showActivityQr(activity);
      } else {
        // ได้ผลลัพธ์เป็น QR Code (EMP_ID) -> เรียก API เช็คอิน
        _processCheckIn(result, activity.actId);
      }
    }
  }

  String _getValidTimeRange(_Activity activity) {
    if (activity.startTime == "-" || activity.endTime == "-") return "TBA";

    try {
      final start = DateFormat("HH:mm").parse(activity.startTime);
      // เวลาเริ่มเปิดให้เช็คอิน (ก่อน 1 ชม.)
      final openTime = start.subtract(const Duration(hours: 1));

      DateTime closeTime;
      if (activity.isCompulsory == 1) {
        // งานบังคับ: ปิดหลังเริ่ม 30 นาที
        closeTime = start.add(const Duration(minutes: 30));
      } else {
        // งานทั่วไป: ปิดตอนจบงาน
        closeTime = DateFormat("HH:mm").parse(activity.endTime);
      }

      return "${DateFormat('HH:mm').format(openTime)} - ${DateFormat('HH:mm').format(closeTime)}";
    } catch (e) {
      return "${activity.startTime} - ${activity.endTime}";
    }
  }

  // 2. เปิดหน้า QR กิจกรรม (Mode B: ให้พนักงานสแกน)
  void _showActivityQr(_Activity activity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityQrDisplayScreen(
          activityName: activity.name,
          actId: activity.actId,
          qrData: "ACTION:CHECKIN|ACT_ID:${activity.actId}",
          timeInfo: _getValidTimeRange(activity), // [NEW] ส่งเวลาที่คำนวณแล้วไป
        ),
      ),
    );
  }

  Future<void> _processCheckIn(String empId, String actId) async {
    // TODO: Implement actual API call
    print("Processing check-in for EMP: $empId at ACT: $actId");
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/activities/$actId/checkin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'empId': empId}),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Check-in Successful!"),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Check-in Failed: ${response.body}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
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
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.black54,
                  size: 28,
                ),
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final hasFilter =
        _selectedTypes.isNotEmpty ||
        _selectedStatus != null ||
        _filterCompulsoryIndex != 0 ||
        _filterOnlyAvailable;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        // เปลี่ยนเป็น Row เพื่อวางปุ่ม Filter คู่กับ Search
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
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Search my activities...',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey[400],
                  ), // แก้สี Hint ให้จางลงหน่อย
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 15.0,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ปุ่ม Filter
          GestureDetector(
            onTap: _showFilterModal,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasFilter
                    ? const Color(0xFF4A80FF)
                    : Colors.white, // เปลี่ยนสีถ้ามีการเลือก Filter
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10.0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.filter_list_rounded,
                color: hasFilter ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                                _selectedStatus = null;
                                _filterCompulsoryIndex = 0;
                                _filterOnlyAvailable = false;
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

                      // 1. Type
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

                      const SizedBox(height: 20),

                      // 2. Status
                      Text(
                        "Status",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: ['Open', 'Full', 'Closed', 'Canceled'].map((
                          status,
                        ) {
                          final isSelected = _selectedStatus == status;
                          return ChoiceChip(
                            label: Text(status),
                            selected: isSelected,
                            selectedColor: const Color(0xFFE6EFFF),
                            labelStyle: GoogleFonts.poppins(
                              color: isSelected
                                  ? const Color(0xFF375987)
                                  : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            onSelected: (bool selected) {
                              setStateModal(() {
                                _selectedStatus = selected ? status : null;
                              });
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 10),

                      // 3. Compulsory
                      Text(
                        "Requirement",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            _buildRadioOption("All", 0, setStateModal),
                            _buildVerticalDivider(),
                            _buildRadioOption("Compulsory", 1, setStateModal),
                            _buildVerticalDivider(),
                            _buildRadioOption("Optional", 2, setStateModal),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 4. Availability
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Show Available Only",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Switch(
                            value: _filterOnlyAvailable,
                            activeColor: const Color(0xFF4A80FF),
                            onChanged: (val) {
                              setStateModal(() => _filterOnlyAvailable = val);
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                      Text(
                        "Hide activities that are fully booked",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A80FF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
                      const SizedBox(height: 10),
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

  Widget _buildRadioOption(String label, int index, StateSetter setStateModal) {
    final isSelected = _filterCompulsoryIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setStateModal(() => _filterCompulsoryIndex = index);
          setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4A80FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1, height: 24, color: Colors.grey.shade300);
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
  final VoidCallback? onScan;

  const _EnterpriseActivityCard({
    required this.activity,
    required this.onTap,
    this.onScan,
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
