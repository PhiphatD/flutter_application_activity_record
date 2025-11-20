import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_application_activity_record/theme/app_colors.dart';
import 'enterprise_scanner_screen.dart';
import 'activities/activity_qr_display_screen.dart';

class ParticipantsDetailsScreen extends StatefulWidget {
  final String activityId;
  final String activityName;
  final DateTime activityDate;
  final String location;
  final bool isHistory;

  // [NEW] เพิ่ม Field เหล่านี้เพื่อใช้คำนวณเวลาในหน้า QR
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
    // [NEW] รับค่าเพิ่ม
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

  List<Map<String, dynamic>> _allParticipants = [];
  List<Map<String, dynamic>> _filteredParticipants = [];

  bool _isLoading = true;
  String _searchQuery = "";

  // Stats
  int _totalRegistered = 0;
  int _totalJoined = 0;

  @override
  void initState() {
    super.initState();
    _fetchParticipants();
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

        if (mounted) {
          setState(() {
            _allParticipants = parsed;
            _filteredParticipants = parsed;
            _totalRegistered = parsed.length;
            _totalJoined = joined;
            _isLoading = false;
          });
          // Apply filter again in case search query exists
          if (_searchQuery.isNotEmpty) _filterList(_searchQuery);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterList(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredParticipants = _allParticipants;
      } else {
        _filteredParticipants = _allParticipants.where((p) {
          final name = p['name'].toString().toLowerCase();
          final dept = p['department'].toString().toLowerCase();
          final search = query.toLowerCase();
          return name.contains(search) || dept.contains(search);
        }).toList();
      }
    });
  }

  // --- [NEW LOGIC START] ส่วนจัดการ Check-in ---

  // 1. ฟังก์ชันคำนวณเวลา (เอาไว้โชว์ใน QR Screen)
  String _getValidTimeRange() {
    if (widget.startTime == "-" || widget.endTime == "-") return "TBA";
    try {
      final start = DateFormat("HH:mm").parse(widget.startTime);
      // เปิดให้เช็คอินก่อน 1 ชม.
      final openTime = start.subtract(const Duration(hours: 1));

      DateTime closeTime;
      if (widget.isCompulsory == 1) {
        // งานบังคับ: ปิดหลังเริ่ม 30 นาที
        closeTime = start.add(const Duration(minutes: 30));
      } else {
        // งานทั่วไป: ปิดตอนจบงาน
        closeTime = DateFormat("HH:mm").parse(widget.endTime);
      }
      return "${DateFormat('HH:mm').format(openTime)} - ${DateFormat('HH:mm').format(closeTime)}";
    } catch (e) {
      return "${widget.startTime} - ${widget.endTime}";
    }
  }

  // 2. แสดง Modal เลือกโหมด
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
                // Option 1: Scan Employee
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
                // Option 2: Show Event QR
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

  // 3. เปิดหน้า Scanner
  void _openScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EnterpriseScannerScreen()),
    );

    if (result != null && mounted) {
      if (result == "SHOW_MY_QR") {
        // กรณีเผื่อไว้
        _openEventQrDisplay();
      } else {
        // ได้ QR Code (EMP_ID) -> ยิง API
        _processCheckIn(result);
      }
    }
  }

  // 4. เปิดหน้าแสดง QR กิจกรรม
  void _openEventQrDisplay() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityQrDisplayScreen(
          activityName: widget.activityName,
          actId: widget.activityId,
          qrData: "ACTION:CHECKIN|ACT_ID:${widget.activityId}",
          timeInfo: _getValidTimeRange(), // ส่งเวลาที่คำนวณแล้วไปแสดง
        ),
      ),
    );
  }

  // 5. ฟังก์ชันยิง API Check-in
  Future<void> _processCheckIn(String empId) async {
    // Show Loading
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

      // Hide Loading
      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        _showResultDialog(
          isSuccess: true,
          title: "Check-in Success!",
          message: "${data['emp_name']}\nEarned +${data['points_earned']} pts",
        );
        _fetchParticipants(); // Refresh list เพื่ออัปเดตสถานะ Joined ทันที
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
  // --- [NEW LOGIC END] ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: organizerBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
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
      ),

      // [NEW] ปุ่ม Check-in มุมขวาล่าง (ซ่อนถ้าเป็น History)
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

      body: Column(
        children: [
          // 1. Summary Dashboard
          _buildDashboard(),

          // 2. Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                onChanged: _filterList,
                decoration: InputDecoration(
                  hintText: "Search by name or department...",
                  hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          // 3. List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredParticipants.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _fetchParticipants,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 8,
                        bottom: 80, // [FIXED] เผื่อที่ให้ FAB ไม่บัง List
                      ),
                      itemCount: _filteredParticipants.length,
                      itemBuilder: (context, index) {
                        return _ParticipantCard(
                          data: _filteredParticipants[index],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  // ... (ส่วน Widget ย่อยอื่นๆ เช่น _buildDashboard, _ParticipantCard ใช้ของเดิมได้เลยครับ)

  Widget _buildDashboard() {
    // ... (Code เดิมของคุณ) ...
    // copy โค้ดเดิมส่วนล่างมาใส่ต่อตรงนี้ได้เลยครับ (ตั้งแต่ _buildDashboard ลงไปจนจบไฟล์)
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
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
                child: _statCard(
                  "Pending",
                  _totalRegistered - _totalJoined,
                  Colors.orange,
                ),
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
          Text(
            "$count",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color.shade800,
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

  const _ParticipantCard({required this.data});

  String _getAvatarUrl(String? title, String empId) {
    final seed = empId;
    if (title == null) {
      return 'https://avatar.iran.liara.run/public/boy?username=$seed';
    }
    final t = title.toLowerCase().trim().replaceAll('.', '');
    if (['ms', 'mrs', 'miss', 'นาง', 'นางสาว'].contains(t)) {
      return 'https://avatar.iran.liara.run/public/girl?username=$seed';
    }
    return 'https://avatar.iran.liara.run/public/boy?username=$seed';
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
              : Colors.grey.shade100,
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
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Registered",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
