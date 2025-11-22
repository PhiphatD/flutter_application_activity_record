import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_activity_record/screens/employee_screens/main/employee_main_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'package:flip_card/flip_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class OrganizerProfileScreen extends StatefulWidget {
  const OrganizerProfileScreen({Key? key}) : super(key: key);

  @override
  State<OrganizerProfileScreen> createState() => _OrganizerProfileScreenState();
}

class _OrganizerProfileScreenState extends State<OrganizerProfileScreen> {
  late Timer _timer;
  Duration _duration = const Duration(minutes: 10);

  String empName = "Loading...";
  String empTitle = "";
  String empId = "...";
  String empPosition = "...";
  String empDepartment = "...";
  String companyName = "...";
  String avatarUrl = "https://i.pravatar.cc/150?img=69";
  String qrData = "";

  String empEmail = "-";
  String empPhone = "-";
  String empStartDateFormatted = "-";
  String serviceDuration = "-";

  final String apiUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";

  @override
  void initState() {
    super.initState();
    _fetchOrganizerProfile();
    _startTimer();
  }

  void _navigateToEmployeeMode() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const EmployeeMainScreen()),
      (route) => false, // ล้าง Stack เพื่อเริ่มใหม่ในโหมด Employee
    );
  }

  Future<void> _fetchOrganizerProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedEmpId = prefs.getString('empId');
    if (storedEmpId == null) return;

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
              DateTime startDate = DateTime.parse(data['EMP_STARTDATE']);
              empStartDateFormatted = DateFormat('d MMM y').format(startDate);
              _calculateServiceDuration(startDate);
            }
          });
        }
      }
    } catch (e) {
      print("Error fetching organizer profile: $e");
    }
  }

  void _calculateServiceDuration(DateTime startDate) {
    final now = DateTime.now();
    final days = now.difference(startDate).inDays;
    final years = days ~/ 365;
    final months = (days % 365) ~/ 30;
    if (mounted) {
      setState(() {
        if (years > 0) {
          serviceDuration =
              "$years Years ${months > 0 ? '$months Months' : ''}";
        } else {
          serviceDuration = "$months Months";
        }
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
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color topGradientColor = Color(0xFFFFF6CC);
    final screenSize = MediaQuery.of(context).size;

    // [POLISH] ใช้ LayoutBuilder เพื่อความแม่นยำสูงสุด
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: topGradientColor,
        elevation: 0,
        foregroundColor: const Color(0xFF375987),
        title: const Text(
          'Organizer Profile',
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
                'Organizer ID',
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
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              }
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

                    // [UPDATED] Responsive Card Container (Perfect Logic)
                    Container(
                      // ความกว้าง: 85% ของจอ แต่ไม่เกิน 380px (สำหรับ iPad) และไม่ต่ำกว่า 300px (สำหรับ iPhone SE)
                      width: (screenSize.width * 0.85).clamp(300.0, 380.0),
                      // ความสูง: ปล่อยให้ AspectRatio จัดการ แต่กำหนด constraints ไว้กันเหนียว
                      constraints: BoxConstraints(
                        maxHeight: screenSize.height * 0.6, // ไม่เกิน 60% ของจอ
                        minHeight: 350, // ไม่ต่ำกว่านี้
                      ),
                      child: AspectRatio(
                        aspectRatio: 0.7, // สัดส่วนบัตรแนวตั้งมาตรฐาน
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
                          'แตะที่บัตรเพื่อพลิก',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: ElevatedButton.icon(
                        onPressed: _navigateToEmployeeMode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF4A80FF),
                          elevation: 2,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFF4A80FF)),
                          ),
                        ),
                        icon: const Icon(Icons.person_outline),
                        label: const Text(
                          "Switch to Participant View",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

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
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 25.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        image: const DecorationImage(
          image: AssetImage('assets/images/card_background_oganize.png'),
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
          // --- [HEADER] ชื่อบริษัท (อยู่บนสุด) ---
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              companyName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF375987),
              ),
            ),
          ),

          // --- [BODY] ส่วนเนื้อหา (จัดกึ่งกลางในพื้นที่ที่เหลือ) ---
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center, // จัดให้อยู่กลางแนวตั้ง
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: NetworkImage(avatarUrl),
                  backgroundColor: Colors.grey.shade200,
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
                    horizontal: 40.0, // บีบเส้นให้สั้นลงหน่อย ดูสวยขึ้น
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
                const SizedBox(height: 6),
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
          image: AssetImage('assets/images/card_background_oganize.png'),
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
        mainAxisSize: MainAxisSize.min,
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
          // [UPDATED] Flexible QR Code
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
            'Show this to Employee to check-in',
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
            value: "$empStartDateFormatted",
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
          color: const Color(0xFFFFF6CC),
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
          // [UPDATED] ใช้ SelectableText หรือ Text ที่ย่อได้
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF375987),
            ),
            overflow: TextOverflow.ellipsis, // กันล้น
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
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
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
