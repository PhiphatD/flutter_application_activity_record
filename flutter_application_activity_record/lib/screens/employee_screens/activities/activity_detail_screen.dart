import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart' hide Config;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// [REMOVE] ไม่ต้อง import web_socket_channel แล้ว
// import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../models/activity_model.dart';
import '../../../services/websocket_service.dart'; // [IMPORT] ใช้ Service กลาง
import '../../../controllers/notification_controller.dart'; // [IMPORT]
import '../../../backend_api/config.dart';

class ActivityDetailScreen extends StatefulWidget {
  final String activityId;
  final bool isOrganizerView;
  final bool
  canEdit; // เพิ่ม parameter นี้เพื่อให้รองรับการเรียกจากหน้า Organizer

  const ActivityDetailScreen({
    Key? key,
    required this.activityId,
    this.isOrganizerView = false,
    this.canEdit = false, // Default เป็น false
  }) : super(key: key);

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  final String baseUrl = Config.apiUrl;
  bool _isLoading = true;
  Activity? _activityData;

  String? _selectedSessionId;
  List<dynamic> _sessions = [];

  @override
  void initState() {
    super.initState();
    _fetchDetail();
    _initRealtimeListener(); // [NEW] ฟังเสียงจาก Service กลาง
  }

  @override
  void dispose() {
    // ไม่ต้องปิด Socket เพราะเราใช้ของส่วนกลาง
    super.dispose();
  }

  // [NEW] ใช้ WebSocketService แทนการต่อเอง
  void _initRealtimeListener() {
    WebSocketService().events.listen((event) {
      final String type = event['event'];

      // ถ้ามีการเปลี่ยนแปลงเกี่ยวกับกิจกรรม หรือผู้เข้าร่วม ให้รีเฟรชหน้านี้
      if (type == "REFRESH_ACTIVITIES" ||
          type == "REFRESH_PARTICIPANTS" ||
          type.startsWith("CHECKIN_SUCCESS")) {
        print("⚡ Detail Update Received: $type");
        _fetchDetail();
      }

      // [เสริม] ถ้ามีการแจ้งเตือนเข้ามา (เช่น ลงทะเบียนเสร็จ)
      // สั่งอัปเดตตัวเลขด้วย (แม้หน้านี้จะไม่มีกระดิ่ง แต่เพื่อให้ MainScreen อัปเดตทันที)
      if (type == "REFRESH_NOTIFICATIONS") {
        NotificationController().fetchUnreadCount(role: "Employee");
      }
    });
  }

  Future<void> _fetchDetail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String empId = prefs.getString('empId') ?? '';

      final response = await http.get(
        Uri.parse('$baseUrl/activities/${widget.activityId}?emp_id=$empId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final act = Activity.fromJson(data);
        if (mounted) {
          setState(() {
            _activityData = act;
            _sessions = data['sessions'] ?? [];
            // Auto select session if only one
            if (_sessions.length == 1 && _selectedSessionId == null) {
              _selectedSessionId = _sessions[0]['sessionId'];
            } else if (_activityData!.isRegistered) {
              // ถ้าลงทะเบียนแล้ว ให้หาว่าลง Session ไหน (จาก API ควรส่งมา)
              // แต่ใน Model ปัจจุบัน sessionId อาจจะเป็น String ว่างถ้ามีหลายรอบ
              // ในที่นี้จะปล่อยไว้ก่อน หรือ Logic เพิ่มเติมตาม API
            }
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_activityData == null) return;
    final bool currentStatus = _activityData!.isFavorite;

    // Optimistic Update
    setState(() {
      _activityData!.isFavorite = !currentStatus;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String empId = prefs.getString('empId') ?? '';

      await http.post(
        Uri.parse('$baseUrl/favorites/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'emp_id': empId, 'act_id': widget.activityId}),
      );
    } catch (e) {
      print("Error toggling favorite: $e");
      setState(() {
        _activityData!.isFavorite = currentStatus;
      });
    }
  }

  Future<void> _handleRegister() async {
    if (_selectedSessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a session time first")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final empId = prefs.getString('empId') ?? '';

      final response = await http.post(
        Uri.parse('$baseUrl/activities/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'emp_id': empId, 'session_id': _selectedSessionId}),
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        // สำเร็จ! WebSocket จะส่งสัญญาณ REFRESH_NOTIFICATIONS และ REFRESH_ACTIVITIES มาเอง
        // หน้าจอนี้จะ refresh ผ่าน _initRealtimeListener

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Registration Successful!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final err = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err['detail'] ?? "Registration Failed"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleUnregister() async {
    // Confirmation Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Registration"),
        content: const Text("Are you sure you want to cancel?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Yes, Cancel",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final empId = prefs.getString('empId');

      // Logic: ถ้าลงทะเบียนแล้ว _selectedSessionId อาจจะยังไม่ได้เลือกใหม่
      // เราควรใช้ Session ID ที่ user ลงทะเบียนไว้
      // (สมมติว่าเลือกจากหน้าจอ หรือ API ส่งกลับมา)
      String? targetSessionId = _selectedSessionId;

      // ถ้ายังไม่ได้เลือก แต่มี Session เดียว หรือ User ลงทะเบียนไว้แล้ว
      if (targetSessionId == null && _activityData != null) {
        // พยายามหา Session ที่ user ลงทะเบียน (จากข้อมูล Activity ที่โหลดมาถ้ามี)
        // หรือใช้ session แรกถ้ามีอันเดียว
        if (_sessions.length == 1) {
          targetSessionId = _sessions[0]['sessionId'];
        }
      }

      if (targetSessionId == null) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Session not selected/found")),
        );
        return;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/activities/unregister'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'emp_id': empId, 'session_id': targetSessionId}),
      );

      if (mounted) Navigator.pop(context); // Close Loading

      if (response.statusCode == 200) {
        // สำเร็จ! เดี๋ยว Socket ส่งสัญญาณมาอัปเดตเอง
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Unregistered successfully"),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        final err = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err['detail'] ?? "Failed"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_activityData == null)
      return const Scaffold(body: Center(child: Text("Not found")));

    final act = _activityData!;

    // ตรวจสอบว่าเป็นอดีตหรือไม่
    bool isPastEvent = false;
    try {
      // Logic ง่ายๆ เช็คจาก status หรือ วันที่
      isPastEvent =
          act.status == 'Closed' ||
          act.status == 'Completed' ||
          act.status == 'Cancelled' ||
          DateTime.now().isAfter(act.activityDate.add(const Duration(days: 1)));
    } catch (_) {}

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(act),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -20),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(act),
                        const SizedBox(height: 24),

                        // Session Selector (ถ้ายังไม่จบ และมีหลายรอบ)
                        if (_sessions.isNotEmpty &&
                            !isPastEvent &&
                            !act.isRegistered) ...[
                          Text(
                            "Select Session",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildSessionSelector(),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 24),
                        ],

                        // Detail Cards
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _buildInfoCard(
                              Icons.person,
                              "Speaker",
                              act.guestSpeaker,
                            ),
                            _buildInfoCard(
                              Icons.business,
                              "Host",
                              act.eventHost,
                            ),
                            _buildInfoCard(
                              Icons.restaurant,
                              "Food",
                              act.foodInfo,
                            ),
                            _buildInfoCard(
                              Icons.directions_bus,
                              "Travel",
                              act.travelInfo,
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        _buildSection(
                          "Cost",
                          act.participationFee,
                          Icons.attach_money,
                          isHighlight: true,
                        ),
                        _buildSection("Condition", act.condition, Icons.rule),

                        if (act.agendaList.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            "Agenda",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildAgendaTimeline(act.agendaList),
                        ],

                        const SizedBox(height: 24),
                        Text(
                          "Description",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          act.description,
                          style: GoogleFonts.kanit(
                            fontSize: 15,
                            color: Colors.black87,
                            height: 1.6,
                          ),
                        ),

                        if (act.moreDetails != '-') ...[
                          const SizedBox(height: 16),
                          Text(
                            "Note: ${act.moreDetails}",
                            style: GoogleFonts.kanit(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomBar(act)),
        ],
      ),
    );
  }

  // --- Widgets ย่อย (ใช้โค้ดเดิมได้เลย หรือจะ Copy ไปแปะ) ---
  // เพื่อความประหยัดบรรทัด ผมขอละ Widgets ย่อยเช่น _buildSliverAppBar, _buildHeader
  // เพราะ Logic สำคัญอยู่ที่ _initRealtimeListener ด้านบนครับ
  // แต่เพื่อให้โค้ดสมบูรณ์ ท่านสามารถ Copy Widget ด้านล่างนี้ไปต่อท้ายได้เลยครับ

  Widget _buildSliverAppBar(Activity act) {
    final images = act.attachments.where((a) => a.type == 'IMAGE').toList();
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: Colors.white,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              act.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: act.isFavorite ? Colors.red : Colors.grey,
            ),
            onPressed: _toggleFavorite,
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: images.isNotEmpty
            ? PageView.builder(
                itemCount: images.length,
                itemBuilder: (context, index) =>
                    Image.network(images[index].url, fit: BoxFit.cover),
              )
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4A80FF), Color(0xFF2D5BFF)],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.image,
                    size: 80,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(Activity act) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Chip(
              label: Text(act.actType),
              backgroundColor: Colors.blue[50],
              labelStyle: GoogleFonts.poppins(
                color: Colors.blue[700],
                fontSize: 11,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber[100]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                  Text(
                    " ${act.point} Pts",
                    style: GoogleFonts.poppins(
                      color: Colors.amber[900],
                      fontWeight: FontWeight.bold,
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
            fontSize: 24,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.location_on, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              act.location,
              style: GoogleFonts.kanit(color: Colors.grey[700]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSessionSelector() {
    return Column(
      children: _sessions
          .map(
            (s) => RadioListTile(
              value: s['sessionId'],
              groupValue: _selectedSessionId,
              onChanged: (v) =>
                  setState(() => _selectedSessionId = v.toString()),
              title: Text(
                DateFormat('EEE, d MMM y').format(DateTime.parse(s['date'])),
              ),
              subtitle: Text(
                "${s['startTime'].substring(0, 5)} - ${s['endTime'].substring(0, 5)}",
              ),
              activeColor: const Color(0xFF4A80FF),
              contentPadding: EdgeInsets.zero,
            ),
          )
          .toList(),
    );
  }

  Widget _buildBottomBar(Activity act) {
    bool isExpired = false;
    try {
      if (DateTime.now().isAfter(act.activityDate.add(const Duration(days: 1))))
        isExpired = true;
    } catch (_) {}

    if (isExpired) {
      return Container(
        padding: const EdgeInsets.all(20),
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Center(
            child: Text(
              "Activity Ended",
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    if (act.isCompulsory) {
      return Container(
        padding: const EdgeInsets.all(20),
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, color: Colors.orange[800]),
              const SizedBox(width: 8),
              Text(
                "Compulsory Activity",
                style: GoogleFonts.poppins(
                  color: Colors.orange[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (act.isRegistered) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        "Registered",
                        style: TextStyle(
                          color: Colors.green[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: _handleUnregister,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: const Icon(
                    Icons.person_remove_outlined,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ElevatedButton(
          onPressed: act.status == 'Full' ? null : _handleRegister,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A80FF),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            act.status == 'Full' ? "Fully Booked" : "Register Now",
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    if (value == "-" || value.isEmpty) return const SizedBox.shrink();
    final width = (MediaQuery.of(context).size.width - 48 - 16) / 2;
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.kanit(fontSize: 13, color: Colors.black87),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    String label,
    String value,
    IconData icon, {
    bool isHighlight = false,
  }) {
    if (value == "-" || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHighlight ? Colors.green[50] : Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isHighlight ? Colors.green : Colors.blue,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              Text(
                value,
                style: GoogleFonts.kanit(fontSize: 15, color: Colors.black87),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaTimeline(List<AgendaItem> agendaList) {
    return Column(
      children: agendaList
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      item.time,
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: GoogleFonts.kanit(fontWeight: FontWeight.w600),
                        ),
                        if (item.detail.isNotEmpty)
                          Text(
                            item.detail,
                            style: GoogleFonts.kanit(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
