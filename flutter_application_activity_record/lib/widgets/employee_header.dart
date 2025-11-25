import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart' hide Config;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../backend_api/config.dart';
import '../models/common/notification_screen.dart';
import '../screens/employee_screens/scan/employee_scanner_screen.dart';
import '../screens/employee_screens/profile/profile_screen.dart';
import '../controllers/notification_controller.dart'; // [IMPORT]

class EmployeeHeader extends StatefulWidget {
  final String title;
  final String subtitle;
  final TextEditingController searchController;
  final String searchHint;
  final VoidCallback? onFilterTap;
  final VoidCallback? onRefresh;
  final Widget? rightActionWidget;

  const EmployeeHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.searchController,
    this.searchHint = 'Search...',
    this.onFilterTap,
    this.onRefresh,
    this.rightActionWidget,
  });

  @override
  State<EmployeeHeader> createState() => _EmployeeHeaderState();
}

class _EmployeeHeaderState extends State<EmployeeHeader> {
  String _avatarUrl = "";

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    // [INIT] ดึงตัวเลขครั้งแรกตอนเปิดหน้า
    NotificationController().fetchUnreadCount(role: 'Employee');
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final empId = prefs.getString('empId') ?? "";
    final cacheKey = 'avatar_cache_${empId}_employee';
    final url = prefs.getString(cacheKey) ?? "";

    if (mounted) setState(() => _avatarUrl = url);

    try {
      final response = await http.get(
        Uri.parse('${Config.apiUrl}/employees/$empId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final empTitle = (data['EMP_TITLE_EN'] ?? "").toLowerCase();
        bool isFemale =
            empTitle.contains("ms") ||
            empTitle.contains("mrs") ||
            empTitle.contains("miss");
        String newUrl = isFemale
            ? "https://avatar.iran.liara.run/public/girl?username=$empId"
            : "https://avatar.iran.liara.run/public/boy?username=$empId";
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
      color: const Color(0xFFF5F7FA),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(_avatarUrl)
                        : const NetworkImage('https://i.pravatar.cc/150?img=32')
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
                        fontSize: 16,
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
              _buildCircleButton(
                icon: Icons.qr_code_scanner,
                color: const Color(0xFF4A80FF),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EmployeeScannerScreen(),
                    ),
                  );
                  if (result == true && widget.onRefresh != null)
                    widget.onRefresh!();
                },
              ),
              const SizedBox(width: 10),

              // [REAL-TIME BADGE] ปุ่มกระดิ่งพร้อมตัวเลข
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const NotificationScreen(currentRole: 'Employee'),
                    ),
                  );
                  // กลับมาแล้วดึงตัวเลขใหม่ (เผื่ออ่านไปแล้ว)
                  NotificationController().fetchUnreadCount(role: 'Employee');
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

                      // [LISTENER] ฟังค่าจาก Controller
                      ValueListenableBuilder<int>(
                        valueListenable: NotificationController().unreadCount,
                        builder: (context, count, child) {
                          if (count == 0)
                            return const SizedBox.shrink(); // ถ้าเป็น 0 ไม่ต้องโชว์
                          return Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Text(
                                count > 9 ? '9+' : '$count',
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              if (widget.rightActionWidget != null) ...[
                const SizedBox(width: 12),
                widget.rightActionWidget!,
              ],
              if (widget.onFilterTap != null) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: widget.onFilterTap,
                  child: Container(
                    height: 50,
                    width: 50,
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
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}
