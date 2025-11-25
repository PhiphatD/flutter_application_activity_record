import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart' hide Config;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
// Import Config และ Controller
import 'package:flutter_application_activity_record/backend_api/config.dart';
import '../../controllers/notification_controller.dart';
// Import ปลายทาง
import 'package:flutter_application_activity_record/screens/employee_screens/activities/activity_detail_screen.dart';


class NotificationScreen extends StatefulWidget {
  final String currentRole;
  const NotificationScreen({super.key, required this.currentRole});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _isLoading = true;
  Map<String, List<dynamic>> _groupedNotifications = {};
  final String baseUrl = Config.apiUrl;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final empId = prefs.getString('empId') ?? '';

      final url = Uri.parse(
        '$baseUrl/notifications/$empId?role=${widget.currentRole}',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));

        // [LOGIC ใหม่] พอได้ข้อมูลมาปุ๊บ สั่ง Mark All Read หลังบ้านทันที
        _markAllAsRead(empId);

        // ส่วนหน้าจอ UI เราก็แสดงผลไปตามปกติ (แต่ในใจเรารู้ว่ามันถูกอ่านแล้ว)
        _groupData(data);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  // [FUNCTION ใหม่] สั่ง Server ว่าอ่านหมดแล้ว และเคลียร์ Badge
  Future<void> _markAllAsRead(String empId) async {
    try {
      // 1. ยิง API เส้นใหม่ที่เพิ่งสร้าง
      await http.put(Uri.parse('$baseUrl/notifications/$empId/read-all'));

      // 2. สั่ง Controller ให้เคลียร์เลขเป็น 0 ทันที
      NotificationController().clear();
    } catch (e) {
      print("Error marking all read: $e");
    }
  }

  void _groupData(List<dynamic> data) {
    // ... (โค้ดเดิม ไม่ต้องแก้)
    Map<String, List<dynamic>> grouped = {};
    for (var notif in data) {
      String dateKey = _formatDateHeader(notif['createdAt']);
      if (grouped[dateKey] == null) grouped[dateKey] = [];
      grouped[dateKey]!.add(notif);
    }
    setState(() {
      _groupedNotifications = grouped;
      _isLoading = false;
    });
  }

  // ... (Helpers _formatDateHeader, _formatTime คงเดิม) ...
  String _formatDateHeader(String? dateString) {
    // ... (เหมือนเดิม)
    if (dateString == null) return "Unknown";
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final checkDate = DateTime(date.year, date.month, date.day);

      if (checkDate == today) return "วันนี้";
      if (checkDate == yesterday) return "เมื่อวานนี้";

      return DateFormat('d MMM yy', 'th').format(date);
    } catch (e) {
      return "Unknown";
    }
  }

  String _formatTime(String? dateString) {
    // ... (เหมือนเดิม)
    if (dateString == null) return "";
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('HH:mm น.').format(date);
    } catch (_) {
      return "";
    }
  }

  // [LOGIC แก้ไข] กดแล้วไปหน้า Detail อย่างเดียว (ไม่ต้อง Mark Read ซ้ำ เพราะทำไปแล้วตอนโหลด)
  void _handleNotificationTap(Map<String, dynamic> notif) {
    final String path = notif['routePath'] ?? '';
    final String refId = notif['refId'] ?? '';

    if (path.isEmpty) return;

    Widget? destination;
    if (path == '/activity_detail' && refId.isNotEmpty) {
      destination = ActivityDetailScreen(activityId: refId);
    } else if (path == '/reward_history') {
      // destination = ...
    }

    if (destination != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => destination!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (UI Build เหมือนเดิมทุกประการ) ...
    return Scaffold(
      backgroundColor: const Color(0xFFECEFF1),
      appBar: AppBar(
        title: Text(
          "การแจ้งเตือน",
          style: GoogleFonts.kanit(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groupedNotifications.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _fetchNotifications,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _groupedNotifications.keys.length,
                itemBuilder: (context, index) {
                  String dateKey = _groupedNotifications.keys.elementAt(index);
                  List<dynamic> items = _groupedNotifications[dateKey]!;
                  return _buildDayGroup(dateKey, items);
                },
              ),
            ),
    );
  }

  // ... (Widgets: _buildDayGroup, _buildEmptyState เหมือนเดิม) ...
  Widget _buildDayGroup(String dateHeader, List<dynamic> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8),
          child: Text(
            dateHeader,
            style: GoogleFonts.kanit(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: List.generate(items.length, (i) {
              bool isLast = i == items.length - 1;
              return Column(
                children: [
                  _buildNotificationItem(items[i]), // เรียกใช้ Widget รายการ
                  if (!isLast)
                    const Divider(
                      height: 1,
                      indent: 70,
                      endIndent: 20,
                      color: Color(0xFFEEEEEE),
                    ),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEmptyState() {
    // ... (เหมือนเดิม)
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "ไม่มีการแจ้งเตือน",
            style: GoogleFonts.kanit(fontSize: 18, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // [UI] แก้ไขเล็กน้อย: เอาจุดแดงออกถาวร หรือจะโชว์แค่ตอนเข้ามาครั้งแรกก็ได้
  // แต่ตามโจทย์คือ "เข้ามาหน้านี้ก็ถือว่าอ่านแล้ว" ดังนั้นเราไม่ต้องโชว์จุดแดงในการ์ดแล้วก็ได้ เพื่อความสะอาด
  Widget _buildNotificationItem(Map<String, dynamic> notif) {
    // *Tip: ถ้าอยากให้ user เห็นว่าอันไหน "เคย" ใหม่ (เป็น Bold) ก่อนหน้านี้
    // ให้ใช้ค่า isRead จาก Database ที่ดึงมา (ซึ่งเป็น False) มาแสดงผล
    // แต่ไม่ต้องสนใจ Logic การกดแล้วเปลี่ยนสถานะ เพราะเราสั่ง Read All ไปแล้วที่หลังบ้าน
    final bool isRead = notif['isRead'] ?? false;
    final String type = notif['type'] ?? 'System';

    IconData iconData;
    Color iconColor;
    Color iconBgColor;

    switch (type) {
      case 'Reward':
        iconData = Icons.card_giftcard;
        iconColor = Colors.green;
        iconBgColor = Colors.green.shade50;
        break;
      case 'Activity':
        iconData = Icons.calendar_today;
        iconColor = Colors.blue;
        iconBgColor = Colors.blue.shade50;
        break;
      case 'Alert':
        iconData = Icons.priority_high_rounded;
        iconColor = Colors.red;
        iconBgColor = Colors.red.shade50;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
        iconBgColor = Colors.grey.shade100;
    }

    return InkWell(
      onTap: () => _handleNotificationTap(notif), // กดเพื่อไปดูดีเทล
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif['title'] ?? 'แจ้งเตือน',
                          style: GoogleFonts.kanit(
                            fontSize: 16,
                            // ถ้าอยากให้เห็นว่าเป็นอันใหม่ (ตัวหนา) ในขณะที่อยู่ในหน้านี้ ก็ใช้ isRead เดิมได้
                            fontWeight: isRead
                                ? FontWeight.w500
                                : FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(notif['createdAt']),
                        style: GoogleFonts.kanit(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif['message'] ?? '',
                    style: GoogleFonts.kanit(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // [LINK] แสดงเฉพาะถ้านำทางได้
                  if (notif['routePath'] != null &&
                      (notif['routePath'] as String).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      "ดูรายละเอียด",
                      style: GoogleFonts.kanit(
                        fontSize: 14,
                        color: const Color(0xFF00A950),
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // จุดแดง (Optional: จะเอาออกเลยก็ได้ เพราะเราถือว่าอ่านแล้วเมื่อเข้าหน้า)
            // แต่ถ้าอยากให้เห็นว่าอันไหนเพิ่งมาใหม่ใน Session นี้ ก็เก็บไว้ได้ครับ
            if (!isRead)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
