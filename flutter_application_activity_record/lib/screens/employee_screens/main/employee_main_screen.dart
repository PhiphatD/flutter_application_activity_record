import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:flutter_application_activity_record/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../activities/activity_feed_screen.dart';
import '../rewards/reward_screen.dart';
import '../activities/todo_screen.dart';
import '../../../controllers/notification_controller.dart';
import '../../../services/websocket_service.dart';

class EmployeeMainScreen extends StatefulWidget {
  const EmployeeMainScreen({super.key});

  @override
  State<EmployeeMainScreen> createState() => _EmployeeMainScreenState();
}

class _EmployeeMainScreenState extends State<EmployeeMainScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ActivityFeedScreenState> _feedKey = GlobalKey();
  String _myEmpId = "";

  @override
  void initState() {
    super.initState();
    _initRealtimeService();
  }

  Future<void> _initRealtimeService() async {
    final prefs = await SharedPreferences.getInstance();
    _myEmpId = prefs.getString('empId') ?? '';

    // [FIXED] เรียก Fetch ครั้งแรกเสมอเพื่อให้เลขตรงตั้งเเต่เปิดแอป
    NotificationController().fetchUnreadCount(role: "Employee");

    if (_myEmpId.isNotEmpty) {
      final wsService = WebSocketService();
      wsService.connect(_myEmpId);

      wsService.events.listen((event) {
        final String type = event['event'];
        final dynamic data = event['data'];

        print("🔔 MainScreen Received Event: $type"); // Debug Log

        // [LOGIC] อัปเดตแจ้งเตือน
        if (type == "REFRESH_NOTIFICATIONS") {
          print("✨ Triggering Badge Update...");
          NotificationController().fetchUnreadCount(role: "Employee");
          _showInAppNotification("You have new notifications 🔔");
        }

        // [LOGIC] อัปเดตหน้า Activity
        if (type == "REFRESH_ACTIVITIES") {
          _feedKey.currentState?.refreshData();
        }

        // [LOGIC] เช็คอินสำเร็จ
        if (type == "CHECKIN_SUCCESS" && data is List) {
          if (data[0] == _myEmpId && data[2] != 'self') {
            _showCheckInSuccessDialog(data[1]);
            _feedKey.currentState?.refreshData();
            NotificationController().fetchUnreadCount(role: "Employee");
          }
        }
      });
    }
  }

  void _showInAppNotification(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Text(message, style: GoogleFonts.poppins()),
          ],
        ),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ... (ฟังก์ชัน _showCheckInSuccessDialog, _onItemTapped และ build เหมือนเดิม)
  void _showCheckInSuccessDialog(String activityName) {
    showDialog(
      context: context,
      barrierDismissible: true,
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
              style: GoogleFonts.poppins(color: Colors.grey[600]),
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
    setState(() => _selectedIndex = index);
    if (index == 0) _feedKey.currentState?.refreshData();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF4A80FF);
    final List<Widget> widgetOptions = <Widget>[
      ActivityFeedScreen(key: _feedKey, onGoToTodo: () => _onItemTapped(1)),
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
