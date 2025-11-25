import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'package:flip_card/flip_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../admin_screens/admin_main_screen.dart';
import '../../organizer_screens/main/organizer_main_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Timer _timer;
  Duration _duration = const Duration(minutes: 10);

  String empName = "Loading...";
  String empTitle = "";
  String empId = "...";
  String empPosition = "...";
  String empDepartment = "...";
  String companyName = "...";
  String avatarUrl = "";
  String qrData = "";
  String empEmail = "-";
  String empPhone = "-";
  String empStartDateFormatted = "-";
  String serviceDuration = "-";
  String userRole = "employee";
  final String apiUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
    _startTimer();
  }

  Future<void> _fetchProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedEmpId = prefs.getString('empId');
    final String? storedRole = prefs.getString('role');

    // [FIXED] 1. กำหนด Role ทันทีและสร้าง Key Cache ตาม Role
    final String effectiveRole = storedRole?.toLowerCase() ?? "employee";
    if (mounted) {
      setState(() {
        userRole = effectiveRole;
      });
    }

    // [FIXED] 2. เช็ค ID ว่างก่อนยิง API
    if (storedEmpId == null || storedEmpId.isEmpty) {
      // ... (Error handling) ...
      return;
    }

    // [FIXED] 3. สร้าง Key Cache ที่มี Role รวมอยู่ด้วย (แก้ปัญหารูปตีกัน)
    final String avatarCacheKey = 'avatar_cache_${storedEmpId}_$effectiveRole';

    // [FIXED] 4. ลองดึงรูปจาก Cache ของ Role นั้นๆ มาแสดงก่อน (Fast Load)
    final String? cachedAvatar = prefs.getString(avatarCacheKey);
    if (mounted && cachedAvatar != null && cachedAvatar.isNotEmpty) {
      setState(() {
        avatarUrl = cachedAvatar;
      });
    }
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/employees/$storedEmpId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            empId = data['EMP_ID'] ?? storedEmpId;
            empTitle = data['EMP_TITLE_EN'] ?? "";
            empName = data['EMP_NAME_EN'] ?? "Unknown";
            empPosition = data['EMP_POSITION'] ?? "-";
            empDepartment = data['DEP_NAME'] ?? "-";
            companyName = data['COMPANY_NAME'] ?? "-";
            empEmail = data['EMP_EMAIL'] ?? "-";
            empPhone = data['EMP_PHONE'] ?? "-";
            qrData = empId;

            if (data['EMP_STARTDATE'] != null) {
              try {
                DateTime startDate = DateTime.parse(data['EMP_STARTDATE']);
                empStartDateFormatted = DateFormat('d MMM y').format(startDate);
                _calculateServiceDuration(startDate);
              } catch (_) {}
            }

            // --- Avatar Logic: ใช้ userRole ที่ถูกดึงมาตอนต้น ---
            bool isFemale = false;
            final lowerTitle = empTitle.toLowerCase();
            if (lowerTitle.contains("ms") ||
                lowerTitle.contains("mrs") ||
                lowerTitle.contains("miss") ||
                lowerTitle.contains("นาง") ||
                lowerTitle.contains("น.ส.")) {
              isFemale = true;
            }

            String newAvatarUrl;
            if (userRole == 'admin') {
              // Admin: Operator Style
              newAvatarUrl = isFemale
                  ? "https://avatar.iran.liara.run/public/girl?username=$empId"
                  : "https://avatar.iran.liara.run/public/boy?username=$empId";
            } else if (userRole == 'organizer') {
              // Organizer: Astronomer Style
              newAvatarUrl = isFemale
                  ? "https://avatar.iran.liara.run/public/girl?username=$empId"
                  : "https://avatar.iran.liara.run/public/boy?username=$empId";
            } else {
              // Employee: Casual Style
              newAvatarUrl = isFemale
                  ? "https://avatar.iran.liara.run/public/girl?username=$empId"
                  : "https://avatar.iran.liara.run/public/boy?username=$empId";
            }

            avatarUrl = newAvatarUrl;
            // [FIXED] 5. บันทึก New URL ลงใน Cache Key ที่มี Role เฉพาะ
            prefs.setString(avatarCacheKey, newAvatarUrl);
          });
        }
      } else {
        print("API Error: ${response.statusCode}");
        if (mounted) {
          setState(() {
            empName = "Data Not Found";
            empPosition = "Server Error (${response.statusCode})";
          });
        }
      }
    } catch (e) {
      print("Error fetching profile: $e");
      if (mounted) {
        setState(() {
          empName = "Connection Error";
          empPosition = "Check Internet";
        });
      }
    }
  }

  void _navigateToAdminMode() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AdminMainScreen()),
      (route) => false,
    );
  }

  void _navigateToOrganizerMode() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const OrganizerMainScreen()),
      (route) => false,
    );
  }

  Widget _buildSwitchButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: color,
        elevation: 2,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color),
        ),
      ),
      icon: Icon(icon),
      label: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _calculateServiceDuration(DateTime startDate) {
    DateTime now = DateTime.now();
    int days = now.difference(startDate).inDays;
    int years = days ~/ 365;
    int months = (days % 365) ~/ 30;
    if (mounted) {
      setState(() {
        if (years > 0)
          serviceDuration =
              "$years Years ${months > 0 ? '$months Months' : ''}";
        else
          serviceDuration = "$months Months";
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_duration.inSeconds > 0) {
            _duration = _duration - const Duration(seconds: 1);
          } else {
            _duration = const Duration(minutes: 10);
            qrData =
                "${empId}_REFRESH_${DateTime.now().millisecondsSinceEpoch}";
          }
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color topGradientColor = Color(0xFFE6EFFF); // สีฟ้าอ่อน
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: topGradientColor,
        elevation: 0,
        foregroundColor: const Color(0xFF375987),
        title: const Text(
          'My Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Color(0xFF375987),
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Column(
            children: [
              const Text(
                'Employee ID',
                style: TextStyle(fontSize: 16, color: Color(0xFF375987)),
              ),
              Text(
                empId,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF375987),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 180,
                ),
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF375987).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF375987)),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (mounted)
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            _buildBackground(topGradientColor),
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    // [UPDATED] Responsive Card
                    Container(
                      width: (screenSize.width * 0.85).clamp(300.0, 380.0),
                      constraints: BoxConstraints(
                        maxHeight: screenSize.height * 0.6,
                        minHeight: 350,
                      ),
                      child: AspectRatio(
                        aspectRatio: 0.7,
                        child: FlipCard(
                          direction: FlipDirection.HORIZONTAL,
                          front: _buildInfoCard(),
                          back: _buildQrCard(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          color: Colors.grey,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Tap card to view QR Code',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // [NEW] ปุ่มสลับโหมดตามสิทธิ์
                    if (userRole == 'organizer' || userRole == 'admin') ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Column(
                          children: [
                            if (userRole == 'admin') ...[
                              // Admin สามารถสลับกลับไปหน้า Admin
                              _buildSwitchButton(
                                title: "Switch to Admin Console",
                                icon: Icons.admin_panel_settings_outlined,
                                onTap: _navigateToAdminMode,
                                color: const Color(
                                  0xFF375987,
                                ), // Dark Blue (Admin)
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Admin และ Organizer สามารถสลับไปหน้า Organizer
                            _buildSwitchButton(
                              title: "Switch to Organizer Console",
                              icon: Icons.dashboard_customize_outlined,
                              onTap: _navigateToOrganizerMode,
                              color: const Color(
                                0xFFFF9F1C,
                              ), // Blue (Organizer)
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    _buildInfoSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(Color topColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [topColor, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(25.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        image: const DecorationImage(
          image: AssetImage('assets/images/card_background.png'),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              companyName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF375987),
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: avatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(avatarUrl)
                      // Fallback: ใช้ NetworkImage ธรรมดาเป็น Placeholder
                      : NetworkImage(
                              'https://avatar.iran.liara.run/username?username=$empName',
                            )
                            as ImageProvider,
                ),
                const SizedBox(height: 15),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$empTitle $empName',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF375987),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32.0,
                    vertical: 10.0,
                  ),
                  child: Divider(
                    color: Colors.black.withOpacity(0.2),
                    thickness: 1,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Position : $empPosition',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      color: Color(0xFF375987),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Department : $empDepartment',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      color: Color(0xFF375987),
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

  Widget _buildQrCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 25.0, horizontal: 25.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        image: const DecorationImage(
          image: AssetImage('assets/images/card_background.png'),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "DIGITAL KEYPASS",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF375987),
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  gapless: false,
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'Show this to Organizer',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF375987)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 32.0,
              vertical: 8.0,
            ),
            child: Divider(color: Colors.black.withOpacity(0.4), thickness: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer, color: Color(0xFF375987)),
              const SizedBox(width: 8),
              Text(
                _formatDuration(_duration),
                style: const TextStyle(fontSize: 20, color: Color(0xFF375987)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoTile(
            icon: Icons.email_outlined,
            label: "Email",
            value: empEmail,
            onTap: () => _copyToClipboard(empEmail, "Email"),
            actionIcon: Icons.copy,
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildInfoTile(
            icon: Icons.phone_outlined,
            label: "Phone",
            value: empPhone,
            onTap: () => _copyToClipboard(empPhone, "Phone Number"),
            actionIcon: Icons.call,
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildInfoTile(
            icon: Icons.calendar_today_outlined,
            label: "Start Date",
            value: empStartDateFormatted,
            subValue: "Duration: $serviceDuration",
            showAction: false,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    String? subValue,
    VoidCallback? onTap,
    IconData? actionIcon,
    bool showAction = true,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFE6EFFF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF375987), size: 22),
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF375987),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          if (subValue != null)
            Text(
              subValue,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
      trailing: showAction
          ? IconButton(
              icon: Icon(
                actionIcon ?? Icons.copy,
                color: Colors.grey.shade400,
                size: 20,
              ),
              onPressed: onTap,
            )
          : null,
      onTap: showAction ? onTap : null,
    );
  }
}
