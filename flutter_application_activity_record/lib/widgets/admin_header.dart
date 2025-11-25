import 'package:flutter/material.dart';
import 'package:flutter_application_activity_record/backend_api/config.dart'
    as app_config;
import 'package:flutter_application_activity_record/models/common/notification_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../backend_api/config.dart';
import '../screens/admin_screens/admin_profile_screen.dart';
import '../controllers/notification_controller.dart';

class AdminHeader extends StatefulWidget {
  final String title;
  final String subtitle;
  final TextEditingController? searchController; // ทำให้เป็น Optional ได้
  final String searchHint;
  final VoidCallback? onFilterTap;
  final Widget? rightActionWidget; // ปุ่มพิเศษอื่นๆ

  const AdminHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.searchController,
    this.searchHint = 'Search...',
    this.onFilterTap,
    this.rightActionWidget,
  });

  @override
  State<AdminHeader> createState() => _AdminHeaderState();
}

class _AdminHeaderState extends State<AdminHeader> {
  String _avatarUrl = "";

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    NotificationController().fetchUnreadCount(role: 'Admin');
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final empId = prefs.getString('empId') ?? "";
    final cacheKey = 'avatar_cache_${empId}_admin';
    final url = prefs.getString(cacheKey) ?? "";

    if (mounted) {
      setState(() => _avatarUrl = url);
    }
    // Logic โหลดรูปถ้าไม่มี Cache
    try {
      final response = await http.get(
        Uri.parse('${app_config.Config.apiUrl}/employees/$empId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final empTitle = (data['EMP_TITLE_EN'] ?? "").toLowerCase();

        bool isFemale =
            empTitle.contains("ms") ||
            empTitle.contains("mrs") ||
            empTitle.contains("miss") ||
            empTitle.contains("นาง") ||
            empTitle.contains("น.ส.");

        String newUrl = isFemale
            ? "https://avatar.iran.liara.run/public/job/operator/female"
            : "https://avatar.iran.liara.run/public/job/operator/male";
        await prefs.setString(cacheKey, newUrl);
        if (mounted) setState(() => _avatarUrl = newUrl);
      }
    } catch (e) {
      debugPrint("Error loading image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FA), // พื้นหลังสีเทาอ่อนมาตรฐาน
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Column(
        children: [
          // --- Row 1: Profile + Texts + Notification ---
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF4A80FF),
                      width: 2,
                    ),
                    color: Colors.white,
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(_avatarUrl)
                        : const NetworkImage(
                                'https://avatar.iran.liara.run/public/job/operator/male',
                              )
                              as ImageProvider,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.2,
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF375987),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          NotificationScreen(currentRole: 'Admin'),
                    ),
                  );
                  NotificationController().fetchUnreadCount(role: 'Admin');
                },
                child: Container(
                  height: 45,
                  width: 45,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_outlined,
                        color: Colors.black54,
                        size: 24,
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable: NotificationController().unreadCount,
                        builder: (context, count, child) {
                          if (count == 0) return const SizedBox.shrink();
                          return Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // --- Row 2: Search Bar (แสดงเฉพาะเมื่อมี Controller) ---
          if (widget.searchController != null) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: widget.searchController,
                      decoration: InputDecoration(
                        hintText: widget.searchHint,
                        hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),

                // Filter Button
                if (widget.onFilterTap != null) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: widget.onFilterTap,
                    child: Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A80FF), // ปุ่มสีฟ้า
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4A80FF).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],

                // ปุ่มเสริมอื่นๆ
                if (widget.rightActionWidget != null) ...[
                  const SizedBox(width: 12),
                  widget.rightActionWidget!,
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
