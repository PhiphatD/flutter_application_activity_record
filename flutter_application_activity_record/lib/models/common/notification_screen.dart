import 'package:flutter/material.dart';
import 'package:flutter_application_activity_record/screens/employee_screens/activities/activity_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart' hide Config;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_activity_record/backend_api/config.dart';
import '../../controllers/notification_controller.dart';

// Import ปลายทางที่จะ Link ไป (ปรับตาม Path จริงของคุณ)

class NotificationScreen extends StatefulWidget {
  final String currentRole; // 'Employee', 'Organizer', 'Admin'

  const NotificationScreen({super.key, required this.currentRole});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _isLoading = true;
  List<dynamic> _notifications = [];
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

      // ยิง API พร้อมส่ง role ไปกรอง
      final url = Uri.parse(
        '$baseUrl/notifications/$empId?role=${widget.currentRole}',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _notifications = data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error fetching notifications: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String notifId, int index) async {
    // Optimistic Update (เปลี่ยนสีทันทีไม่ต้องรอ)
    if (!_notifications[index]['isRead']) {
      setState(() {
        _notifications[index]['isRead'] = true;
      });

      // [NEW] ลดจำนวน Badge ลงทันที
      NotificationController().decreaseCount();

      try {
        await http.put(Uri.parse('$baseUrl/notifications/$notifId/read'));
      } catch (e) {
        print("Error marking read: $e");
        // ถ้า Error ให้ดึงใหม่เพื่อความชัวร์
        NotificationController().fetchUnreadCount(role: widget.currentRole);
      }
    }
  }

  // ฟังก์ชัน Deep Link: กดแล้วไปไหน?
  void _handleNotificationTap(Map<String, dynamic> notif, int index) {
    _markAsRead(notif['notifId'], index);

    final String path = notif['routePath'] ?? '';
    final String refId = notif['refId'] ?? '';

    if (path.isEmpty) return;

    Widget? destination;

    // --- Routing Logic ---
    if (path == '/activity_detail' && refId.isNotEmpty) {
      destination = ActivityDetailScreen(activityId: refId);
    } else if (path == '/reward_history') {
      // สมมติว่าไปหน้ารายการแลก (อาจต้องสร้าง RedeemedDetail แบบรับ ID ได้)
      // destination = RedeemedDetailScreen(redeemId: refId);
      // เบื้องต้นพาไปหน้า Detail ถ้ามี ID
    } else if (path == '/participants' && refId.isNotEmpty) {
      // ฝั่ง Organizer: ไปหน้าดูคนเข้าร่วม
      // ต้องหาข้อมูลกิจกรรมเพิ่มเติมก่อน หรือส่งแค่ ID ไปถ้าหน้าปลายทางรองรับ
      // destination = ParticipantsDetailsScreen(activityId: refId, ...);
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          "Notifications",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _fetchNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _fetchNotifications,
              child: ListView.builder(
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  return _buildNotificationItem(_notifications[index], index);
                },
              ),
            ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notif, int index) {
    final bool isRead = notif['isRead'] ?? false;
    final String type = notif['type'] ?? 'System';
    final String dateStr = _formatDate(notif['createdAt']);

    IconData icon;
    Color color;

    switch (type) {
      case 'Reward':
        icon = Icons.card_giftcard;
        color = Colors.orange;
        break;
      case 'Activity':
        icon = Icons.event_available;
        color = Colors.blue;
        break;
      case 'Alert':
        icon = Icons.warning_amber_rounded;
        color = Colors.red;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.purple;
    }

    return Container(
      color: isRead ? Colors.white : Colors.blue.withOpacity(0.05),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Stack(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.1),
                  child: Icon(icon, color: color, size: 22),
                ),
                if (!isRead)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              notif['title'] ?? '',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  notif['message'] ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  dateStr,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
            onTap: () => _handleNotificationTap(notif, index),
          ),
          const Divider(height: 1, indent: 70),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 50,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "No notifications yet",
            style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return "";
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return "Just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes} mins ago";
      if (diff.inHours < 24) return "${diff.inHours} hours ago";
      if (diff.inDays < 2) return "Yesterday";
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return "";
    }
  }
}
