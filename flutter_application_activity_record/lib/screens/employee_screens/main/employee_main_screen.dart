import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:flutter_application_activity_record/theme/app_colors.dart';

import '../activities/activity_feed_screen.dart';
import '../rewards/reward_screen.dart';
import '../activities/todo_screen.dart';
import '../activities/activity_feed_screen.dart';
import '../scan/employee_scanner_screen.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmployeeMainScreen extends StatefulWidget {
  const EmployeeMainScreen({super.key});

  @override
  State<EmployeeMainScreen> createState() => _EmployeeMainScreenState();
}

class _EmployeeMainScreenState extends State<EmployeeMainScreen> {
  int _selectedIndex = 0;

  // [NEW] สร้าง GlobalKey เพื่อสั่งงานหน้า ActivityFeed
  final GlobalKey<ActivityFeedScreenState> _feedKey = GlobalKey();
  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  void _connectWebSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final myEmpId = prefs.getString('empId') ?? '';

    try {
      // ใช้ IP เครื่องคุณ หรือ ngrok url
      final wsUrl = Uri.parse(
        'ws://numerably-nonevincive-kyong.ngrok-free.dev/ws',
      );
      _channel = WebSocketChannel.connect(wsUrl);

      _channel!.stream.listen((message) {
        // Message Format: "CHECKIN_SUCCESS|EMP_ID|ACT_NAME|SCANNED_BY"
        if (message.toString().startsWith("CHECKIN_SUCCESS|")) {
          final parts = message.toString().split('|');
          if (parts.length >= 4) {
            final empId = parts[1];
            final actName = parts[2];
            final scannedBy = parts[3];

            // เงื่อนไข: เป็น ID เรา และ เราไม่ได้สแกนเอง (Organizer สแกนให้)
            if (empId == myEmpId && scannedBy != 'self') {
              if (mounted) {
                _showCheckInSuccessDialog(actName);
                // สั่ง Refresh ข้อมูลในหน้า Feed (ถ้าทำได้) หรือปล่อยให้ Socket ในหน้าลูกทำงาน
              }
            }
          }
        }
      });
    } catch (e) {
      print("WS Error: $e");
    }
  }

  void _showCheckInSuccessDialog(String activityName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Check-in Successful!",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You have been checked in to\n\"$activityName\"",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("OK", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // [NEW] ถ้ากดกลับมาหน้าแรก (index 0) ให้สั่งรีเฟรชข้อมูล
    if (index == 0) {
      _feedKey.currentState?.refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF4A80FF);

    // ใช้ List ใน build เพื่อส่ง key และ callback
    final List<Widget> widgetOptions = <Widget>[
      ActivityFeedScreen(
        key: _feedKey, // [NEW] ผูก Key ไว้ที่นี่
        onGoToTodo: () => _onItemTapped(1),
      ),
      const TodoScreen(),
      const RewardScreen(),
    ];

    return Scaffold(
      backgroundColor: employeeBg,
      body: IndexedStack(index: _selectedIndex, children: widgetOptions),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 10.0,
            ),
            child: SalomonBottomBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              duration: const Duration(milliseconds: 400),
              items: [
                SalomonBottomBarItem(
                  icon: const Icon(Icons.grid_view_outlined),
                  activeIcon: const Icon(Icons.grid_view_rounded),
                  title: Text(
                    "Activity",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  selectedColor: primaryColor,
                ),
                SalomonBottomBarItem(
                  icon: const Icon(Icons.checklist_outlined),
                  activeIcon: const Icon(Icons.checklist_rounded),
                  title: Text(
                    "To do",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  selectedColor: primaryColor,
                ),
                SalomonBottomBarItem(
                  icon: const Icon(Icons.card_giftcard_outlined),
                  activeIcon: const Icon(Icons.card_giftcard_rounded),
                  title: Text(
                    "Reward",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  selectedColor: primaryColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
