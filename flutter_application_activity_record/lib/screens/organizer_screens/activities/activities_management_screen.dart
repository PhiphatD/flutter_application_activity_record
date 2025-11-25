import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'activity_create_screen.dart';
import 'activity_edit_screen.dart';
import 'activity_detail_screen.dart';

import '../participants/enterprise_scanner_screen.dart';
import '../../../widgets/organizer_header.dart';

class ActivityManagementScreen extends StatefulWidget {
  const ActivityManagementScreen({super.key});

  @override
  State<ActivityManagementScreen> createState() =>
      _ActivityManagementScreenState();
}

class _ActivityManagementScreenState extends State<ActivityManagementScreen> {
  // --- [FIXED] ย้าย baseUrl มาไว้ตรงนี้ เพื่อให้ทุกฟังก์ชันเรียกใช้ได้ ---
  final String baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";

  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  String _currentOrgId = '';
  List<String> _selectedTypes = [];
  String? _selectedStatus;
  List<String> _availableTypes = [];
  WebSocketChannel? _channel;
  int _filterCompulsoryIndex = 0;
  bool _filterOnlyAvailable = false;
  int _selectedOwnerSegment = 0;
  int _selectedTimeFilter = 0;

  bool _isLoading = true;
  List<Activity> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.trim();
      });
    });
    _connectWebSocket();
  }

  void _connectWebSocket() {
    try {
      final wsUrl = Uri.parse(
        'ws://numerably-nonevincive-kyong.ngrok-free.dev/ws',
      );
      _channel = WebSocketChannel.connect(wsUrl);

      _channel!.stream.listen((message) {
        // [CHECK] ต้องมี REFRESH_ACTIVITIES อยู่ในนี้
        if (message == "REFRESH_ACTIVITIES" ||
            message == "REFRESH_PARTICIPANTS" ||
            message.toString().contains("CHECKIN_SUCCESS")) {
          print("⚡ Real-time Update: $message");
          _fetchActivities();
        }
      }, onError: (e) => print("WS Error: $e"));
    } catch (e) {
      print("WS Connection Failed: $e");
    }
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentOrgId = prefs.getString('orgId') ?? '';
    });
    _fetchActivities(); // โหลดกิจกรรมหลังจากได้ ID แล้ว
  }

  Future<void> _fetchActivities() async {
    // [REMOVED] ลบการประกาศ local variable ออก
    final url = Uri.parse('$baseUrl/activities');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final loadedActivities = data
            .map((json) => Activity.fromJson(json))
            .toList();

        final types = loadedActivities.map((a) => a.actType).toSet().toList();
        if (mounted) {
          setState(() {
            _activities = data.map((json) => Activity.fromJson(json)).toList();
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

  // 1. ดึงกิจกรรมวันนี้ของฉัน (Reuse Logic)
  Future<List<Activity>> _fetchMyActivitiesToday() async {
    try {
      // ใช้ข้อมูล _activities ที่มีอยู่แล้ว กรองเอาเลยเพื่อความเร็ว
      final today = DateTime.now();

      final myTodayActs = _activities.where((a) {
        // เช็คว่าเป็นของฉัน (เทียบกับ orgId ที่โหลดมา)
        if (a.orgId != _currentOrgId) return false;

        if (a.status == 'Closed' || a.status == 'Cancelled') return false;

        final actDate = a.activityDate;
        final isToday =
            actDate.year == today.year &&
            actDate.month == today.month &&
            actDate.day == today.day;
        return isToday;
      }).toList();

      return myTodayActs;
    } catch (e) {
      print("Error fetching activities today: $e");
    }
    return [];
  }

  // 2. ฟังก์ชันหลักเมื่อกดปุ่ม Scan
  void _handleSmartScan() async {
    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    final activities = await _fetchMyActivitiesToday();

    if (!mounted) return;
    Navigator.pop(context); // Close Loading

    if (activities.isEmpty) {
      _showErrorDialog(
        "No Activities Today",
        "คุณไม่มีกิจกรรมที่จัดขึ้นในวันนี้ หรือกิจกรรมยังไม่เปิด",
      );
    } else if (activities.length == 1) {
      // เจอ 1 อัน -> ลุยเลย!
      final act = activities.first;
      _openScanner(act.actId, act.name);
    } else {
      // เจอหลายอัน -> ให้เลือกก่อน
      _showActivitySelectionSheet(activities);
    }
  }

  // [UI] Popup เลือกกิจกรรม
  void _showActivitySelectionSheet(List<Activity> activities) {
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

  // [SCANNER] เปิดกล้อง
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
        Uri.parse(
          '$baseUrl/checkin',
        ), // ตอนนี้ใช้งานได้แล้ว เพราะ baseUrl เป็น Class Member
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
        // Refresh List เพื่ออัปเดตตัวเลขผู้เข้าร่วม
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

  @override
  void dispose() {
    _searchController.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  List<Activity> _filteredActivities() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _activities.where((a) {
      final isMine = a.orgId == _currentOrgId;
      final ownerMatch = (_selectedOwnerSegment == 0) ? isMine : !isMine;

      final actDate = DateTime(
        a.activityDate.year,
        a.activityDate.month,
        a.activityDate.day,
      );

      bool timeMatch;
      if (_selectedTimeFilter == 0) {
        timeMatch = !actDate.isBefore(today);
      } else {
        timeMatch = actDate.isBefore(today);
      }

      if (_selectedTypes.isNotEmpty && !_selectedTypes.contains(a.actType)) {
        return false;
      }

      if (_selectedStatus != null && a.status != _selectedStatus) {
        return false;
      }

      if (_filterCompulsoryIndex == 1 && a.isCompulsory == 0) return false;
      if (_filterCompulsoryIndex == 2 && a.isCompulsory == 1) return false;

      if (_filterOnlyAvailable) {
        if (a.maxParticipants > 0 &&
            a.currentParticipants >= a.maxParticipants) {
          return false;
        }
      }

      if (_searchText.isEmpty) {
        return ownerMatch && timeMatch;
      }

      final searchLower = _searchText.toLowerCase();
      final matchName = a.name.toLowerCase().contains(searchLower);
      final matchLocation = a.location.toLowerCase().contains(searchLower);
      final matchOrg = a.organizerName.toLowerCase().contains(searchLower);

      return ownerMatch &&
          timeMatch &&
          (matchName || matchLocation || matchOrg);
    }).toList();
  }

  Map<DateTime, List<Activity>> _groupActivities(List<Activity> list) {
    if (_selectedTimeFilter == 0) {
      list.sort((a, b) => a.activityDate.compareTo(b.activityDate));
    } else {
      list.sort((a, b) => b.activityDate.compareTo(a.activityDate));
    }

    Map<DateTime, List<Activity>> groups = {};
    for (var activity in list) {
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

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF6CC), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.4],
        ),
      ),
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
                      Text(
                        "Status",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: ['Open', 'Full', 'Closed', 'Cancelled'].map((
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
                            "Done",
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

  void _deleteActivity(String actId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/activities/$actId'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _activities.removeWhere((a) => a.actId == actId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Activity deleted successfully")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ใช้ Stack เพื่อซ้อนพื้นหลัง
      floatingActionButton: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: FloatingActionButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateActivityScreen()),
              );
              _fetchActivities();
            },
            backgroundColor: const Color(0xFF4A80FF),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(color: const Color(0xFFF5F7FA)),
          SafeArea(
            child: Column(
              children: [
                OrganizerHeader(
                  title: "Welcome Organizer",
                  subtitle: "Manage your activities",
                  searchController: _searchController,
                  searchHint: "Search activities...",
                  onFilterTap: _showFilterModal,
                  onScanSuccess: _handleSmartScan,
                ),

                // [FIXED] คืนชีพ Filter Chips (My Activities / Others) กลับมา
                Container(
                  color: const Color.fromARGB(255, 255, 255, 255),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildChipSelector(
                          "My Activities",
                          _selectedOwnerSegment == 0,
                          () => setState(() => _selectedOwnerSegment = 0),
                        ),
                        const SizedBox(width: 8),
                        _buildChipSelector(
                          "Others",
                          _selectedOwnerSegment == 1,
                          () => setState(() => _selectedOwnerSegment = 1),
                        ),
                        Container(
                          height: 24,
                          width: 1,
                          color: Colors.grey.shade300,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        _buildChipSelector(
                          "Active",
                          _selectedTimeFilter == 0,
                          () => setState(() => _selectedTimeFilter = 0),
                          isStatus: true,
                        ),
                        const SizedBox(width: 8),
                        _buildChipSelector(
                          "History",
                          _selectedTimeFilter == 1,
                          () => setState(() => _selectedTimeFilter = 1),
                          isStatus: true,
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchActivities,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildGroupedList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList() {
    final filteredList = _filteredActivities();

    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedTimeFilter == 0 ? Icons.event_available : Icons.history,
              size: 80, // ขยายใหญ่ขึ้น
              color: Colors.grey[200],
            ),
            const SizedBox(height: 16),
            Text(
              _selectedTimeFilter == 0
                  ? "You don't have any activities yet."
                  : 'No history found',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // [NEW UX] ปุ่มสร้างกิจกรรมตรงกลาง
            if (_selectedTimeFilter == 0 && _selectedOwnerSegment == 0)
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateActivityScreen(),
                    ),
                  );
                  _fetchActivities();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A80FF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                  shadowColor: const Color(0xFF4A80FF).withOpacity(0.4),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text(
                  "Create New Activity",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              )
            else
              TextButton.icon(
                onPressed: _fetchActivities,
                icon: const Icon(Icons.refresh),
                label: const Text("Refresh Data"),
              ),
          ],
        ),
      );
    }

    final groupedMap = _groupActivities(filteredList);
    final dateKeys = groupedMap.keys.toList();

    return RefreshIndicator(
      onRefresh: _fetchActivities,
      child: ListView.builder(
        padding: const EdgeInsets.only(
          left: 20.0,
          right: 20.0,
          top: 10.0,
          bottom: 80.0,
        ),
        itemCount: dateKeys.length,
        itemBuilder: (context, index) {
          final date = dateKeys[index];
          final activitiesOnDate = groupedMap[date]!;
          final isMine = _selectedOwnerSegment == 0;
          return _buildActivityGroup(date, activitiesOnDate, isMine);
        },
      ),
    );
  }

  Widget _buildActivityGroup(
    DateTime date,
    List<Activity> activities,
    bool mine,
  ) {
    final isToday = _isSameDay(date, DateTime.now());
    final bool isHistoryTab = _selectedTimeFilter == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 12.0),
          child: Row(
            children: [
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
                _formatActivityDate(date),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isToday ? Colors.black : Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _getRelativeDateString(date),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        ...activities.map((a) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _OrganizerActivityCard(
              status: a.status,
              id: a.actId,
              type: a.actType,
              title: a.name,
              location: a.location,
              organizer: a.organizerName,
              points: a.point,
              currentParticipants: a.currentParticipants,
              maxParticipants: a.maxParticipants,
              isCompulsory: a.isCompulsory == 1,
              showActions:
                  mine &&
                  _selectedTimeFilter ==
                      0, // แก้ไขได้เฉพาะของฉัน และเป็น Active
              startTime: a.startTime,
              endTime: a.endTime,
              isHistory: isHistoryTab,
              onEdit: () async {
                final bool? result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditActivityScreen(actId: a.actId),
                  ),
                );
                if (result == true) _fetchActivities();
              },
              onDelete: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(
                      'Confirm Delete',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                    content: Text(
                      'Delete this activity?',
                      style: GoogleFonts.poppins(),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Cancel', style: GoogleFonts.poppins()),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          'Delete',
                          style: GoogleFonts.poppins(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (ok == true) _deleteActivity(a.actId);
              },
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ActivityDetailScreen(
                      activityId: a.actId,
                      isOrganizerView: true,

                      // [FIX] ส่งสิทธิ์การแก้ไขเข้าไป
                      // แก้ได้เฉพาะเมื่อ: เป็นของฉัน (mine) AND อยู่ในแท็บ Active (_selectedTimeFilter == 0)
                      canEdit: mine && _selectedTimeFilter == 0,
                    ),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ],
    );
  }

  // Helper Widget สำหรับปุ่มเลือกเล็กๆ (Chip) - คงเดิม
  Widget _buildChipSelector(
    String label,
    bool isSelected,
    VoidCallback onTap, {
    bool isStatus = false,
  }) {
    // กำหนดสีที่แน่นอน
    Color bgColor;
    Color textColor;
    Color borderColor;

    if (isSelected) {
      if (isStatus) {
        // Active/History Tab (Blue Theme)
        bgColor = const Color(0xFFE6EFFF);
        textColor = const Color(0xFF4A80FF);
        borderColor = const Color(0xFF4A80FF);
      } else {
        // My/Others Tab (Orange/Yellow Theme)
        bgColor = const Color(0xFFFFF8E1);
        textColor = Colors.amber.shade900;
        borderColor = Colors.amber;
      }
    } else {
      // Unselected State
      bgColor = Colors.white;
      textColor = Colors.grey.shade600;
      borderColor = Colors.grey.shade300;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor.withOpacity(0.5), width: 1),
          // เพิ่มเงาเล็กน้อยเมื่อเลือก เพื่อให้ดูเด่นขึ้น (ลดอาการดูเหมือนกระพริบ)
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: borderColor.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: isSelected
                ? FontWeight.w600
                : FontWeight.normal, // ปรับน้ำหนักฟอนต์
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            _buildTimeFilterTab("Active", 0),
            _buildTimeFilterTab("History", 1),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeFilterTab(String text, int index) {
    final isSelected = _selectedTimeFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTimeFilter = index),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? Colors.black : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  String _formatActivityDate(DateTime eventDate) {
    final formatter = DateFormat('d MMMM y', 'en_US');
    return formatter.format(eventDate);
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

    if (differenceInDays < 0) return "Past Event";
    if (differenceInDays == 0) return "Today";
    if (differenceInDays == 1) return "Tomorrow";
    if (differenceInDays <= 7) return "This Week";
    return "";
  }
}

// Activity Model
class Activity {
  final String actId;
  final String orgId;
  final String actType;
  final int isCompulsory;
  final int point;
  final String name;
  final int currentParticipants;
  final int maxParticipants;
  final String status;
  final String location;
  final String organizerName;
  final DateTime activityDate;
  final String startTime;
  final String endTime;

  Activity({
    required this.actId,
    required this.orgId,
    required this.actType,
    required this.isCompulsory,
    required this.point,
    required this.name,
    required this.currentParticipants,
    required this.maxParticipants,
    required this.status,
    required this.location,
    required this.organizerName,
    required this.activityDate,
    required this.startTime,
    required this.endTime,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    DateTime date = DateTime.now();
    if (json['activityDate'] != null) {
      date = DateTime.parse(json['activityDate']);
    }
    return Activity(
      actId: json['actId']?.toString() ?? '',
      orgId: json['orgId']?.toString() ?? '',
      actType: json['actType'] ?? '',
      isCompulsory: json['isCompulsory'] ?? 0,
      point: json['point'] ?? 0,
      name: json['name'] ?? '',
      currentParticipants: json['currentParticipants'] ?? 0,
      maxParticipants: json['maxParticipants'] ?? 0,
      status: json['status'] ?? 'Open',
      location: json['location'] ?? '-',
      organizerName: json['organizerName'] ?? '-',
      activityDate: date,
      startTime: json['startTime'] ?? '-',
      endTime: json['endTime'] ?? '-',
    );
  }
}

class _OrganizerActivityCard extends StatelessWidget {
  final String status;
  final String id;
  final String type;
  final String title;
  final String location;
  final String organizer;
  final int points;
  final int currentParticipants;
  final int maxParticipants;
  final bool isCompulsory;
  final bool showActions;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final String startTime;
  final String endTime;
  final bool isHistory; // ตัวแปรสำคัญ

  const _OrganizerActivityCard({
    super.key,
    required this.id,
    required this.type,
    required this.title,
    required this.location,
    required this.organizer,
    required this.points,
    required this.currentParticipants,
    required this.maxParticipants,
    required this.isCompulsory,
    required this.showActions,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
    required this.status,
    this.startTime = "-",
    this.endTime = "-",
    this.isHistory = false,
  });

  Color _getTypeColor(String type) {
    // ถ้าเป็น History ให้คืนค่าสีเทาเสมอ เพื่อสื่อว่าเป็นอดีต
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
    final typeColor = _getTypeColor(type);
    final bool isFull =
        maxParticipants > 0 && currentParticipants >= maxParticipants;

    // [UX Improvement] ทำให้การ์ด History ดูจางลงเล็กน้อย
    final displayOpacity = isHistory ? 0.7 : 1.0;

    // --- Status Logic ---
    Color statusBg;
    Color statusTextCol;
    String displayStatus;

    if (isHistory) {
      // ถ้าเป็น History บังคับโชว์ "Ended" สีเทา
      displayStatus = "Ended";
      statusBg = Colors.grey.shade200;
      statusTextCol = Colors.grey.shade600;
    } else {
      // ถ้าเป็น Active โชว์ตามจริง
      displayStatus = status;
      switch (status) {
        case 'Full':
          statusBg = Colors.red.shade50;
          statusTextCol = Colors.red;
          break;
        case 'Closed':
          statusBg = Colors.grey.shade100;
          statusTextCol = Colors.grey.shade700;
          break;
        default: // Open
          statusBg = const Color(0xFFE6EFFF);
          statusTextCol = const Color(0xFF4A80FF);
      }
    }

    return Opacity(
      opacity: displayOpacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white, // ยังคงพื้นหลังขาวเพื่อให้ clean
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                isHistory ? 0.02 : 0.05,
              ), // เงาจางลงถ้าเป็น History
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Side Bar (Grey if history)
                  Container(
                    width: 6,
                    color: typeColor, // ใช้สีที่คำนวณไว้ (เทา หรือ สีตามประเภท)
                  ),

                  // 2. Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- Tags Row ---
                          Row(
                            children: [
                              // Type Tag
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
                                  type.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Status Tag (Ended or Open)
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
                                  displayStatus,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: statusTextCol,
                                  ),
                                ),
                              ),

                              const Spacer(),
                              // [Hidden Menu for History]
                              if (showActions && !isHistory)
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    icon: Icon(
                                      Icons.more_horiz,
                                      color: Colors.grey.shade400,
                                    ),
                                    onSelected: (v) {
                                      if (v == 'edit') onEdit();
                                      if (v == 'delete') onDelete();
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (isHistory)
                                // แสดงไอคอน Lock แทนเมนู เพื่อบอกว่าแก้ไขไม่ได้
                                Icon(
                                  Icons.lock_outline,
                                  size: 14,
                                  color: Colors.grey.shade300,
                                ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // --- Title ---
                          Text(
                            title,
                            style: GoogleFonts.kanit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              // ถ้าเป็น History สีชื่อจะดรอปลงนิดนึง
                              color: isHistory
                                  ? Colors.grey.shade700
                                  : const Color(0xFF1F2937),
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 6),

                          // --- Time & Location ---
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                startTime != "-" ? startTime : "TBA",
                                style: GoogleFonts.kanit(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  location,
                                  style: GoogleFonts.kanit(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // --- Progress & Stats ---
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.group_outlined,
                                          size: 16,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          // History: เน้นยอดสรุป, Active: เน้นเป้า
                                          isHistory
                                              ? "Total: $currentParticipants"
                                              : "$currentParticipants/$maxParticipants",
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    // Progress Bar
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value: maxParticipants > 0
                                            ? currentParticipants /
                                                  maxParticipants
                                            : 0,
                                        backgroundColor: Colors.grey.shade100,
                                        // History: Progress Bar สีเทา
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              isHistory
                                                  ? Colors.grey.shade400
                                                  : (isFull
                                                        ? Colors.red
                                                        : typeColor),
                                            ),
                                        minHeight: 3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Points Badge (Grey if history)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isHistory
                                      ? Colors.grey.shade100
                                      : Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isHistory
                                        ? Colors.transparent
                                        : Colors.amber.shade100,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: isHistory
                                          ? Colors.grey.shade400
                                          : Colors.amber.shade800,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "$points",
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isHistory
                                            ? Colors.grey.shade500
                                            : Colors.amber.shade900,
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
