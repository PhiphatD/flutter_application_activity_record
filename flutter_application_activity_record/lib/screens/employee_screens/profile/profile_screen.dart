import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'package:flip_card/flip_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Timer _timer;
  Duration _duration = const Duration(minutes: 10);

  // --- ตัวแปรข้อมูลพนักงาน ---
  String empName = "Loading...";
  String empTitle = "";
  String empId = "...";
  String empPosition = "...";
  String empDepartment = "...";
  String companyName = "...";
  String avatarUrl = "https://i.pravatar.cc/150?img=12";
  String qrData = "";

  // --- ตัวแปรใหม่สำหรับ Lower Section ---
  String empEmail = "-";
  String empPhone = "-";
  String empStartDateFormatted = "-";
  String serviceDuration = "-";

  // API URL
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

    if (storedEmpId == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiUrl/employees/$storedEmpId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

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
    } catch (e) {
      print("Error fetching profile: $e");
    }
  }

  void _calculateServiceDuration(DateTime startDate) {
    DateTime now = DateTime.now();
    int days = now.difference(startDate).inDays;
    int years = days ~/ 365;
    int months = (days % 365) ~/ 30;

    setState(() {
      if (years > 0) {
        serviceDuration = "$years Years ${months > 0 ? '$months Months' : ''}";
      } else {
        serviceDuration = "$months Months";
      }
    });
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
    // สีเริ่มต้นของ Gradient (ใช้เป็นสี AppBar ด้วยเพื่อความเนียน)
    const Color topGradientColor = Color(0xFFE6EFFF);

    return Scaffold(
      // 1. ปิดการขยาย Body ไปหลัง AppBar เพื่อแก้ปัญหาทับซ้อน
      extendBodyBehindAppBar: false,

      appBar: AppBar(
        // 2. เปลี่ยนสีพื้นหลัง AppBar ให้ตรงกับสีเริ่มของ Gradient
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
            _buildBackground(topGradientColor), // ส่งสีเข้าไป
            SingleChildScrollView(
              // 3. ปรับ Padding หลังย้ายหัวข้อขึ้น AppBar
              padding: const EdgeInsets.only(bottom: 20),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    // --- Flip Card Section ---
                    SizedBox(
                      height: 450,
                      child: FlipCard(
                        direction: FlipDirection.HORIZONTAL,
                        front: _buildInfoCard(),
                        back: _buildQrCard(),
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

                    // --- Lower Section: Information List ---
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

  Widget _buildBackground(Color topColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [topColor, Colors.white], // ใช้สีที่ส่งเข้ามาเพื่อให้เนียน
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  // ... (ส่วน Card Widgets อื่นๆ คงเดิม) ...
  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30.0),
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
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            companyName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF375987),
            ),
          ),
          const SizedBox(height: 15),
          CircleAvatar(radius: 60, backgroundImage: NetworkImage(avatarUrl)),
          const SizedBox(height: 15),
          Text(
            '$empTitle $empName',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF375987),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 32.0,
              vertical: 8.0,
            ),
            child: Divider(color: Colors.black.withOpacity(0.4), thickness: 1),
          ),
          Text(
            'Position : $empPosition',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, color: Color(0xFF375987)),
          ),
          const SizedBox(height: 5),
          Text(
            'Department : $empDepartment',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, color: Color(0xFF375987)),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30.0),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'DIGITAL KEYPASS',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF375987),
            ),
          ),
          const SizedBox(height: 15),
          QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: 181.0,
            gapless: false,
          ),
          const SizedBox(height: 15),
          const Text(
            'Show this to Organizer to check-in',
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
}
