import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_application_activity_record/theme/app_colors.dart';

class ParticipantsDetailsScreen extends StatefulWidget {
  final String activityId;
  final String activityName;
  final DateTime activityDate;
  final String location;

  const ParticipantsDetailsScreen({
    super.key,
    required this.activityId,
    required this.activityName,
    required this.activityDate,
    required this.location,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
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

  Widget _buildDashboard() {
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
              // [FIX] Wrap with Flexible to prevent overflow
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

  // [NEW] ฟังก์ชันเลือกรูปการ์ตูนตามเพศ (จาก Title)
  String _getAvatarUrl(String? title, String empId) {
    // ใช้ Service ของ avatar.iran.liara.run ซึ่งฟรีและมีแยกเพศชัดเจน
    final seed = empId; // ใช้ empId เป็น seed ให้หน้าตาเหมือนเดิมทุกครั้ง

    if (title == null)
      return 'https://avatar.iran.liara.run/public/boy?username=$seed';

    final t = title.toLowerCase().trim().replaceAll('.', '');

    // เช็คคำนำหน้าผู้หญิง
    if (['ms', 'mrs', 'miss', 'นาง', 'นางสาว'].contains(t)) {
      return 'https://avatar.iran.liara.run/public/girl?username=$seed';
    }

    // Default เป็นผู้ชาย (Mr. หรืออื่นๆ)
    return 'https://avatar.iran.liara.run/public/boy?username=$seed';
  }

  @override
  Widget build(BuildContext context) {
    final isJoined = data['status'] == 'Joined';
    final empId = data['empId'] ?? '';
    final title = data['title']; // รับ Title มาจาก API

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
            // [UPDATED] ใช้รูปการ์ตูน
            backgroundImage: NetworkImage(_getAvatarUrl(title, empId)),
          ),
          const SizedBox(width: 16),

          // [FIXED] Expanded เพื่อให้ข้อความยาวๆ ไม่ล้นจอ
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
                    // [FIXED] Expanded ซ้อนใน Row เพื่อกันล้น
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

          const SizedBox(width: 8), // ระยะห่างระหว่างข้อความกับป้ายสถานะ
          // Status Badge
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
