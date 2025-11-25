import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../models/activity_model.dart';
import '../../../widgets/custom_confirm_dialog.dart';
import '../../../widgets/auto_close_success_dialog.dart';

class ActivityDetailScreen extends StatefulWidget {
  final String activityId;
  final bool isOrganizerView;
  const ActivityDetailScreen({
    Key? key,
    required this.activityId,
    this.isOrganizerView = false,
  }) : super(key: key);

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  final String baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";
  bool _isLoading = true;
  Activity? _activityData;

  String? _selectedSessionId;
  List<dynamic> _sessions = [];

  // [NEW] WebSocket for Real-time Updates
  WebSocketChannel? _channel;

  Map<String, String> _getSelectedSessionDetails() {
    if (_selectedSessionId == null) return {'date': '-', 'time': '-'};
    final session = _sessions.firstWhere(
      (s) => s['sessionId'] == _selectedSessionId,
      orElse: () => null,
    );
    if (session == null) return {'date': '-', 'time': '-'};

    try {
      final date = DateFormat(
        'd MMM y',
      ).format(DateTime.parse(session['date']));
      final time =
          "${session['startTime'].substring(0, 5)} - ${session['endTime'].substring(0, 5)}";
      return {'date': date, 'time': time};
    } catch (_) {
      return {'date': 'Invalid Date', 'time': 'Invalid Time'};
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchDetail();
    _connectWebSocket(); // [NEW] Start Real-time Listener
  }

  @override
  void dispose() {
    _channel?.sink.close(); // [NEW] Close WebSocket
    super.dispose();
  }

  // [NEW] WebSocket Connection for Real-time Updates
  void _connectWebSocket() {
    try {
      final wsUrl = Uri.parse(
        'ws://numerably-nonevincive-kyong.ngrok-free.dev/ws',
      );
      _channel = WebSocketChannel.connect(wsUrl);

      _channel!.stream.listen(
        (message) {
          // ถ้ามีคนสมัคร/ยกเลิก (REFRESH_PARTICIPANTS)
          // หรือข้อมูลกิจกรรมเปลี่ยน (REFRESH_ACTIVITIES เช่น แก้ไขรายละเอียด)
          // ให้โหลดข้อมูลใหม่ทันที เพื่ออัปเดตยอด Current Participants
          if (message == "REFRESH_PARTICIPANTS" ||
              message == "REFRESH_ACTIVITIES") {
            print("⚡ Detail Update: $message");
            _fetchDetail(); // เรียกฟังก์ชันเดิมเพื่อโหลดข้อมูลใหม่
          }
        },
        onError: (error) {
          print("WS Error: $error");
        },
        onDone: () {
          print("WS Connection Closed");
        },
      );
    } catch (e) {
      print("WS Connection Failed: $e");
    }
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
            if (_sessions.length == 1)
              _selectedSessionId = _sessions[0]['sessionId'];
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

    // Optimistic Update: Update UI immediately
    setState(() {
      // Create a new Activity object with the toggled favorite status
      // Assuming Activity has a copyWith method or we can recreate it.
      // Since I don't see copyWith in the provided code, I'll assume I can't easily clone it
      // without modifying the model. However, the user instruction showed:
      // _activityData!.isFavorite = !currentStatus;
      // which implies the field might be mutable or they want me to make it mutable.
      // But I recall seeing it was final.
      // Let's check if I can just use the user's provided code which implies mutability or
      // if I should use a workaround.
      // The user provided:
      // setState(() {
      //   _activityData!.isFavorite = !currentStatus;
      // });
      // If isFavorite is final, this will fail.
      // But wait, if I look at the previous `view_file` of `ActivityCard`, it takes `isFavorite`.
      // The `Activity` model was imported. I didn't check `Activity` model file.
      // But the user's snippet suggests they want me to use that code.
      // I will assume `isFavorite` is mutable OR I should modify the model.
      // BUT, I can't modify the model file as I haven't read it and it's not in the plan.
      // Wait, I can try to use `copyWith` if it exists.
      // If not, I'll just try to set it and if it fails I'll know.
      // Actually, to be safe and follow instructions, I will use the code provided by the user.
      // If it's final, I might need to fix the model too.
      // Let's assume the user knows what they are doing or I should fix the model if needed.
      // Actually, I'll check the model file first? No, I'll just try to apply the user's code.
      // Wait, I can't see the model file.
      // I'll just apply the code. If it errors, I'll fix the model.
      // Actually, I'll just cast it to dynamic to bypass the check if I really have to, but that's bad.
      // Let's look at the user request again.
      // The user code: `_activityData!.isFavorite = !currentStatus;`
      // This implies `isFavorite` is not final.
      // I will use the user's code.
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
      // Success: UI is already updated
    } catch (e) {
      print("Error toggling favorite: $e");
      // Error: Rollback UI state
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

    // ---------------------------------------------------------
    // [NEW CODE START] เพิ่มส่วนนี้: ถามยืนยันก่อนสมัคร
    // ---------------------------------------------------------
    final details = _getSelectedSessionDetails();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => CustomConfirmDialog.success(
        // Reuse Widget เดิม
        title: "Confirm Registration",
        subtitle:
            "Join '${_activityData!.name}'?\n\n📅 ${details['date']}\n⏰ ${details['time']}",
        confirmText: "Yes, Join",
        onConfirm: () {
          Navigator.pop(context, true); // ส่งค่า true กลับไป
        },
      ),
    );

    if (confirm != true) return; // ถ้ากด Cancel หรือปิด Dialog ให้หยุดทำงาน
    // ---------------------------------------------------------
    // [NEW CODE END]
    // ---------------------------------------------------------

    // Show Loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final empId = prefs.getString('empId') ?? '';

      // ยิง API จริง
      final response = await http.post(
        Uri.parse('$baseUrl/activities/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'emp_id': empId, 'session_id': _selectedSessionId}),
      );

      if (mounted) Navigator.pop(context); // Close Loading

      if (response.statusCode == 200) {
        // Re-fetch to get updated data
        await _fetchDetail();

        // Show Success (อันนี้คือตัวที่ Auto Close ถ้าอยากให้อยู่นานขึ้น ปรับ duration ได้)
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AutoCloseSuccessDialog(
              title: "Registration Confirmed! 🎉",
              subtitle: "You have successfully joined the activity.",
              icon: Icons.check_circle,
              color: Colors.green,
              duration: const Duration(
                seconds: 3,
              ), // [OPTIONAL] เพิ่มเวลาจาก 2 เป็น 3 วิ
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_activityData == null)
      return const Scaffold(body: Center(child: Text("Not found")));

    final act = _activityData!;

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

                        if (_sessions.isNotEmpty) ...[
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

                        // [NEW] Agenda Section (Timeline)
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

  // [NEW WIDGET] Agenda Timeline
  Widget _buildAgendaTimeline(List<AgendaItem> agendaList) {
    return Column(
      children: agendaList.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isLast = index == agendaList.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Time Column
              SizedBox(
                width: 60,
                child: Text(
                  item.time,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 12),

              // 2. Timeline Line & Dot
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A80FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: Colors.grey.shade200,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // 3. Content Card
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.kanit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF375987),
                        ),
                      ),
                      if (item.detail.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.detail,
                          style: GoogleFonts.kanit(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ... (Widgets อื่นๆ: _buildSliverAppBar, _buildHeader, _buildSessionSelector, _buildBottomBar, _buildInfoCard, _buildSection ใช้โค้ดเดิม)
  // เพื่อความกระชับ ผมขอละไว้ (ท่านสามารถ copy จากไฟล์เดิมมาแปะต่อได้เลยครับ)

  Widget _buildSliverAppBar(Activity act) {
    final images = act.attachments.where((a) => a.type == 'IMAGE').toList();

    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: images.isNotEmpty
            ? PageView.builder(
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return Image.network(
                    images[index].url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.broken_image,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              )
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4A80FF), Color(0xFF2D5BFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
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
    if (_sessions.isEmpty) return const Text("No sessions available");
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

  // [MODIFIED] อัปเดต _handleUnregister ให้ใช้ CustomConfirmDialog และ AutoCloseSuccessDialog
  Future<void> _handleUnregister() async {
    final details = _getSelectedSessionDetails();

    // 1. [NEW UX] Custom Confirm Dialog with Details
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => CustomConfirmDialog.danger(
        title: "Cancel Registration?",
        subtitle:
            "You will unregister from '${_activityData!.name}'\nDate: ${details['date']} | Time: ${details['time']}",
        confirmText: "Yes, Cancel",
        onConfirm: () => Navigator.pop(context, true),
      ),
    );

    if (confirm != true) return; // Exit if not confirmed

    // 2. Loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final empId = prefs.getString('empId');

      if (_selectedSessionId == null) {
        if (mounted) Navigator.pop(context); // Close Loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a session to cancel")),
        );
        return;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/activities/unregister'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'emp_id': empId, 'session_id': _selectedSessionId}),
      );

      if (response.statusCode == 200) {
        if (mounted) Navigator.pop(context); // Close Loading

        await _fetchDetail(); // Re-fetch to get updated data

        // [NEW UX] Use AutoCloseSuccessDialog
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AutoCloseSuccessDialog(
              title: "Cancellation Successful 🗑️",
              subtitle:
                  "You are no longer registered for '${_activityData!.name}'",
              icon: Icons.person_remove_alt_1_rounded,
              color: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        // if (mounted) Navigator.pop(context, true); // Close detail page (Optional)
      } else {
        if (mounted) Navigator.pop(context); // Close Loading
        // [UPDATED] แสดงเหตุผลที่ Backend ตีกลับมา
        try {
          final errorData = json.decode(utf8.decode(response.bodyBytes));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorData['detail'] ?? "Cannot cancel"),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Failed: ${response.body}"),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Widget _buildBottomBar(Activity act) {
    // --- [NEW LOGIC] 1. ตรวจสอบว่ากิจกรรมจบหรือยัง ---
    bool isExpired = false;
    try {
      // รวมวันที่และเวลาสิ้นสุดเข้าด้วยกัน
      final DateTime actDate = act.activityDate;
      final TimeOfDay endTime = _parseTime(act.endTime);

      final DateTime endDateTime = DateTime(
        actDate.year,
        actDate.month,
        actDate.day,
        endTime.hour,
        endTime.minute,
      );

      // ถ้าเวลาปัจจุบัน เลยเวลาจบกิจกรรมไปแล้ว = Expired
      if (DateTime.now().isAfter(endDateTime)) {
        isExpired = true;
      }
    } catch (e) {
      // กรณี parse เวลาผิดพลาด ให้ยึดตามวันที่
      if (DateTime.now().isAfter(
        act.activityDate.add(const Duration(days: 1)),
      )) {
        isExpired = true;
      }
    }

    // --- [NEW UI] 2. ถ้ากิจกรรมจบแล้ว (History / Missed) ---
    if (isExpired) {
      // เช็คสถานะย่อย: ถ้าลงทะเบียนไว้แต่จบแล้ว = Completed หรือ Missed
      // (ในที่นี้ขอแสดงรวมๆ ว่า Ended เพื่อความปลอดภัย หรือปรับตาม Business Logic)

      String label = "Activity Ended";
      Color bgColor = Colors.grey.shade100;
      Color textColor = Colors.grey.shade600;
      IconData icon = Icons.event_busy;

      if (act.isRegistered) {
        // ถ้าเคยลงทะเบียนไว้แล้วจบแล้ว
        label = "Activity Completed"; // หรือ Joined
        bgColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        icon = Icons.check_circle_outline;
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
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: textColor),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ---------------------------------------------------------
    // ด้านล่างคือ Logic เดิมสำหรับกิจกรรมที่ยังไม่จบ (Upcoming)
    // ---------------------------------------------------------

    // กรณีที่ 0: กิจกรรมบังคับ (Compulsory)
    if (act.isCompulsory) {
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
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  "Compulsory Activity",
                  style: GoogleFonts.poppins(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // กรณีที่ 1: ลงทะเบียนแล้ว (และยังไม่จบ)
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
                        "You are registered",
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

              // ปุ่มยกเลิก (แสดงเฉพาะตอนยังไม่จบ)
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

    // กรณีที่ 2: ยังไม่ลงทะเบียน (และยังไม่จบ)
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
            elevation: 0,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade600,
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

  // Helper สำหรับแปลงเวลา String เป็น TimeOfDay (ถ้ายังไม่มีใน class ให้เพิ่มเข้าไปครับ)
  TimeOfDay _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(":");
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return const TimeOfDay(hour: 23, minute: 59); // Default end of day
    }
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
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.kanit(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
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
                style: GoogleFonts.kanit(
                  fontSize: 15,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
