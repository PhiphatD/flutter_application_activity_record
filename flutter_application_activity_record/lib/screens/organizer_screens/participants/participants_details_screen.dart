import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'enterprise_scanner_screen.dart';
import 'activities/activity_qr_display_screen.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ParticipantsDetailsScreen extends StatefulWidget {
  final String activityId;
  final String activityName;
  final DateTime activityDate;
  final String location;
  final bool isHistory;

  final String startTime;
  final String endTime;
  final int isCompulsory;

  const ParticipantsDetailsScreen({
    super.key,
    required this.activityId,
    required this.activityName,
    required this.activityDate,
    required this.location,
    required this.isHistory,
    this.startTime = "-",
    this.endTime = "-",
    this.isCompulsory = 0,
  });

  @override
  State<ParticipantsDetailsScreen> createState() =>
      _ParticipantsDetailsScreenState();
}

class _ParticipantsDetailsScreenState extends State<ParticipantsDetailsScreen> {
  final String baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";
  WebSocketChannel? _channel;
  List<Map<String, dynamic>> _allParticipants = [];
  List<Map<String, dynamic>> _filteredParticipants = [];

  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Stats
  int _totalRegistered = 0;
  int _totalJoined = 0;

  // Filter State
  String? _selectedStatusFilter; // All, Joined, Registered/Absent
  String? _selectedDepartmentFilter; // All, IT, HR, ...
  List<String> _availableDepartments = []; // Dynamic List

  @override
  void initState() {
    super.initState();
    _fetchParticipants();
    _searchController.addListener(_onSearchChanged);
    _connectWebSocket();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
        // ถ้ามีข้อความว่ามีการเช็คอิน หรือ อัปเดตข้อมูล
        if (message == "REFRESH_PARTICIPANTS" ||
            message.toString().contains("CHECKIN_SUCCESS")) {
          print("⚡ Real-time update received!");
          _fetchParticipants(); // โหลดข้อมูลใหม่ทันที
        }
      }, onError: (e) => print("WS Error: $e"));
    } catch (e) {
      print("WS Connection Failed: $e");
    }
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  Future<void> _fetchParticipants() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse(
        '$baseUrl/activities/${widget.activityId}/participants',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        List<Map<String, dynamic>> parsed = List<Map<String, dynamic>>.from(
          data,
        );

        // Calculate stats
        int joined = parsed.where((p) => p['status'] == 'Joined').length;

        // Extract unique departments for filter
        final depts = parsed
            .map((p) => p['department'] as String? ?? "-")
            .toSet()
            .toList();
        depts.sort();

        if (mounted) {
          setState(() {
            _allParticipants = parsed;
            _filteredParticipants = parsed;
            _totalRegistered = parsed.length;
            _totalJoined = joined;
            _availableDepartments = depts;
            _isLoading = false;
          });
          _applyFilters(); // Apply default filters (All)
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // [CORE LOGIC] Smart Filtering
  void _applyFilters() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredParticipants = _allParticipants.where((p) {
        // 1. Search Text
        final name = (p['name'] ?? "").toString().toLowerCase();
        final dept = (p['department'] ?? "").toString().toLowerCase();
        final empId = (p['empId'] ?? "").toString().toLowerCase();
        final matchesSearch =
            name.contains(query) ||
            dept.contains(query) ||
            empId.contains(query);

        // 2. Status Filter
        bool matchesStatus = true;
        if (_selectedStatusFilter != null) {
          final pStatus = p['status']; // "Joined" or "Registered"

          if (_selectedStatusFilter == 'Joined') {
            matchesStatus = pStatus == 'Joined';
          } else if (_selectedStatusFilter == 'Not Joined') {
            // Not Joined = Registered (ยังไม่เช็คอิน) หรือ Absent (ถ้าจบงานแล้ว)
            matchesStatus = pStatus != 'Joined';
          }
        }

        // 3. Department Filter
        bool matchesDept = true;
        if (_selectedDepartmentFilter != null) {
          matchesDept = (p['department'] ?? "-") == _selectedDepartmentFilter;
        }

        return matchesSearch && matchesStatus && matchesDept;
      }).toList();
    });
  }

  // [UI] Filter Modal (Fixed Bottom Padding)
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // [FIX 1] เปิดโหมดนี้เพื่อให้ Modal ยืดหยุ่น
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            // [FIX 2] คำนวณ Padding เองเพื่อความชัวร์ (24px + พื้นที่ Safe Area ด้านล่าง)
            final bottomPadding = MediaQuery.of(context).padding.bottom + 24;

            return Container(
              padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Filter Participants",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedStatusFilter = null;
                            _selectedDepartmentFilter = null;
                          });
                          _applyFilters();
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

                  // Status Filter
                  Text(
                    "Status",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip(
                        "All",
                        _selectedStatusFilter == null,
                        () {
                          setStateModal(() => _selectedStatusFilter = null);
                        },
                      ),
                      _buildFilterChip(
                        "Joined",
                        _selectedStatusFilter == 'Joined',
                        () {
                          setStateModal(() => _selectedStatusFilter = 'Joined');
                        },
                      ),
                      _buildFilterChip(
                        widget.isHistory ? "Absent" : "Pending",
                        _selectedStatusFilter == 'Not Joined',
                        () {
                          setStateModal(
                            () => _selectedStatusFilter = 'Not Joined',
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Department Filter
                  Text(
                    "Department",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        "All",
                        _selectedDepartmentFilter == null,
                        () {
                          setStateModal(() => _selectedDepartmentFilter = null);
                        },
                      ),
                      ..._availableDepartments.map((dept) {
                        return _buildFilterChip(
                          dept,
                          _selectedDepartmentFilter == dept,
                          () {
                            setStateModal(
                              () => _selectedDepartmentFilter = dept,
                            );
                          },
                        );
                      }).toList(),
                    ],
                  ),

                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _applyFilters();
                        Navigator.pop(context);
                      },
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

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFFFFF6CC), // Theme Yellow
      checkmarkColor: Colors.orange.shade900,
      labelStyle: GoogleFonts.poppins(
        color: isSelected ? Colors.orange.shade900 : Colors.black87,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      onSelected: (_) => onTap(),
    );
  }

  // --- Check-in Logic ---
  String _getValidTimeRange() {
    if (widget.startTime == "-" || widget.endTime == "-") return "TBA";
    try {
      final start = DateFormat("HH:mm").parse(widget.startTime);
      final openTime = start.subtract(const Duration(hours: 1));
      DateTime closeTime;
      if (widget.isCompulsory == 1) {
        closeTime = start.add(const Duration(minutes: 30));
      } else {
        closeTime = DateFormat("HH:mm").parse(widget.endTime);
      }
      return "${DateFormat('HH:mm').format(openTime)} - ${DateFormat('HH:mm').format(closeTime)}";
    } catch (e) {
      return "${widget.startTime} - ${widget.endTime}";
    }
  }

  void _showCheckInOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Text(
                    "Check-in Mode",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.blue,
                    ),
                  ),
                  title: Text(
                    "Scan Employee QR",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    "Organizer scans employee's phone",
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _openScanner();
                  },
                ),
                const Divider(indent: 20, endIndent: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.qr_code_2, color: Colors.orange),
                  ),
                  title: Text(
                    "Show Event QR",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    "Employee scans this screen",
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _openEventQrDisplay();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EnterpriseScannerScreen()),
    );

    if (result != null && mounted) {
      if (result == "SHOW_MY_QR") {
        _openEventQrDisplay();
      } else {
        _processCheckIn(result);
      }
    }
  }

  void _openEventQrDisplay() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityQrDisplayScreen(
          activityName: widget.activityName,
          actId: widget.activityId,
          qrData: "ACTION:CHECKIN|ACT_ID:${widget.activityId}",
          timeInfo: _getValidTimeRange(),
        ),
      ),
    );
  }

  Future<void> _processCheckIn(String empId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/checkin'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "emp_id": empId,
          "act_id": widget.activityId,
          "scanned_by": "organizer",
        }),
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        _showResultDialog(
          isSuccess: true,
          title: "Check-in Success!",
          message: "${data['emp_name']}\nEarned +${data['points_earned']} pts",
        );
        _fetchParticipants();
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        _showResultDialog(
          isSuccess: false,
          title: "Check-in Failed",
          message: errorData['detail'] ?? "Unknown error",
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showResultDialog(
        isSuccess: false,
        title: "Connection Error",
        message: "Cannot connect to server.",
      );
    }
  }

  void _showResultDialog({
    required bool isSuccess,
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.cancel,
              color: isSuccess ? Colors.green : Colors.red,
              size: 80,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isSuccess ? Colors.green[800] : Colors.red[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 16),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSuccess ? Colors.green : Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  "OK",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFilter =
        _selectedStatusFilter != null || _selectedDepartmentFilter != null;

    // [UPDATED] ไม่ต้องใช้ตัวแปร topGradientColor แล้ว เพราะเราจะใช้สีขาว

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white, // [UPDATED] เปลี่ยนเป็นสีขาว
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(
          "Participants",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        // [OPTIONAL] ถ้าต้องการให้ Status Bar ไอคอนเป็นสีดำชัดเจน
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      floatingActionButton: widget.isHistory
          ? null
          : FloatingActionButton.extended(
              onPressed: _showCheckInOptions,
              backgroundColor: const Color(0xFF4A80FF),
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              label: Text(
                "Check-in",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
      body: Stack(
        // [UPDATED] ใช้ Stack
        children: [
          _buildBackground(), // [UPDATED] วางพื้นหลังไว้ล่างสุด
          SafeArea(
            child: Column(
              children: [
                // 1. Dashboard
                _buildDashboard(),

                // 2. Search & Filter Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: "Search name, dept...",
                              hintStyle: GoogleFonts.poppins(
                                color: Colors.grey[400],
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.grey[400],
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Filter Button
                      GestureDetector(
                        onTap: _showFilterModal,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: hasFilter
                                ? const Color(0xFF4A80FF)
                                : Colors.white,
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
                            Icons.filter_list_rounded,
                            color: hasFilter
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. List
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredParticipants.isEmpty
                      ? RefreshIndicator(
                          // [NEW] Wrap Empty State ด้วย
                          onRefresh: _fetchParticipants,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: _buildEmptyState(),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          // [NEW] Wrap ListView ด้วย RefreshIndicator
                          onRefresh: _fetchParticipants,
                          color: const Color(0xFF4A80FF),
                          child: ListView.builder(
                            physics:
                                const AlwaysScrollableScrollPhysics(), // สำคัญ! ต้องมีเพื่อให้ลากได้
                            padding: const EdgeInsets.only(
                              left: 20,
                              right: 20,
                              top: 8,
                              bottom: 80,
                            ),
                            itemCount: _filteredParticipants.length,
                            itemBuilder: (context, index) {
                              return _ParticipantCard(
                                data: _filteredParticipants[index],
                                isHistory: widget.isHistory,
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // [UPDATED] ปรับพื้นหลัง: ขาว (บน) -> เหลือง (กลาง) -> ขาว (ล่าง)
  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white, // เริ่มต้นด้วยสีขาว (ส่วน AppBar/Header)
            Color(0xFFFFF6CC), // ตรงกลางเป็นสีเหลืองอ่อน (Theme)
            Colors.white, // ไล่กลับไปเป็นสีขาวด้านล่าง
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // กำหนดจุดเปลี่ยนสี:
          // 0.0 - 0.15 : ขาวล้วน
          // 0.15 - 0.4 : ไล่ไปเหลือง
          // 0.4 - 1.0  : ไล่กลับไปขาว
          stops: [0.0, 0.15, 0.6],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    // คำนวณ Pending/Absent Label
    final pendingLabel = widget.isHistory ? "Absent" : "Pending";
    final pendingColor = widget.isHistory ? Colors.red : Colors.orange;

    // คำนวณยอด Pending
    final pendingCount = _totalRegistered - _totalJoined;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              0.08,
            ), // [UPDATED] เงาเข้มขึ้นนิดนึง
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        // [UPDATED] เพิ่มขอบบางๆ ให้ดูตัดกับพื้นหลังสีขาว
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.activityName,
            style: GoogleFonts.kanit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF375987),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                DateFormat('d MMM y').format(widget.activityDate),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  widget.location,
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
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _statCard("Registered", _totalRegistered, Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(child: _statCard("Joined", _totalJoined, Colors.green)),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(pendingLabel, pendingCount, pendingColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, int count, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade100),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "$count",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color.shade800,
              ),
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(fontSize: 12, color: color.shade600),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(
            "No participants found",
            style: GoogleFonts.poppins(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isHistory;

  const _ParticipantCard({required this.data, required this.isHistory});

  String _getAvatarUrl(String? title, String empId) {
    return "https://avatar.iran.liara.run/public/boy?username=$empId";
  }

  @override
  Widget build(BuildContext context) {
    final isJoined = data['status'] == 'Joined';
    final empId = data['empId'] ?? '';
    final title = data['title'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isJoined
              ? Colors.green.withOpacity(0.3)
              : (isHistory
                    ? Colors.red.withOpacity(0.2)
                    : Colors.grey.shade100),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: NetworkImage(_getAvatarUrl(title, empId)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'] ?? 'Unknown',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "$empId • ${data['department'] ?? '-'}",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          if (isJoined)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Joined",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "at ${data['checkInTime']}",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            )
          else if (isHistory)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Absent",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: data['status'] == 'Assigned'
                    ? Colors
                          .purple
                          .shade50 // สีม่วงสำหรับ Assigned (Compulsory)
                    : Colors.orange.shade50, // สีส้มสำหรับ Registered (General)
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                data['status'] ??
                    "Pending", // แสดงคำว่า Assigned หรือ Registered
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: data['status'] == 'Assigned'
                      ? Colors.purple.shade700
                      : Colors.orange.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
