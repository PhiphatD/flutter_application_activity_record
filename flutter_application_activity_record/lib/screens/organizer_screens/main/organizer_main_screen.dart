import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:flutter_application_activity_record/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Services & Controllers
import '../../../services/websocket_service.dart';
import '../../../controllers/notification_controller.dart';

// Import Screens
import '../activities/activities_management_screen.dart';
import '../participants/activities_participants_list_screen.dart';

class OrganizerMainScreen extends StatefulWidget {
  const OrganizerMainScreen({super.key});

  @override
  State<OrganizerMainScreen> createState() => _OrganizerMainScreenState();
}

class _OrganizerMainScreenState extends State<OrganizerMainScreen> {
  int _selectedIndex = 0;
  String _myEmpId = "";

  // [FIXED] ใช้ GlobalKey<State> ธรรมดา เพื่อแก้ปัญหา Private Type Not Found
  final GlobalKey<State> _manageKey = GlobalKey();
  final GlobalKey<State> _participantKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initRealtimeService();
  }

  Future<void> _initRealtimeService() async {
    final prefs = await SharedPreferences.getInstance();
    _myEmpId = prefs.getString('empId') ?? '';

    // 1. ดึงตัวเลขแจ้งเตือนเริ่มต้น
    NotificationController().fetchUnreadCount(role: "Organizer");

    if (_myEmpId.isNotEmpty) {
      final wsService = WebSocketService();
      wsService.connect(_myEmpId);

      wsService.events.listen((event) async {
        final String type = event['event'];
        final dynamic data = event['data'];

        // print("🔔 Organizer Event Received: $type");

        // CASE A: มีแจ้งเตือนใหม่
        if (type == "REFRESH_NOTIFICATIONS") {
          NotificationController().fetchUnreadCount(role: "Organizer");
          if (mounted) _showTopToast("New notification received 🔔");
        }

        // CASE B: ข้อมูลกิจกรรมมีการเปลี่ยนแปลง
        if (type == "REFRESH_ACTIVITIES" ||
            type == "REFRESH_PARTICIPANTS" ||
            type == "CHECKIN_SUCCESS") {
          print("⚡ Refreshing All Tabs...");

          // [DYNAMIC CALL] สั่ง Refresh Tab 1: Manage
          if (_manageKey.currentState != null) {
            // ใช้ dynamic เพื่อเรียกฟังก์ชัน โดยไม่ต้องรู้ Type จริง
            try {
              (_manageKey.currentState as dynamic).refreshData();
            } catch (e) {
              print("Error refreshing Manage Tab: $e");
            }
          }

          // [DYNAMIC CALL] สั่ง Refresh Tab 2: Participants
          if (_participantKey.currentState != null) {
            try {
              (_participantKey.currentState as dynamic).refreshData();
            } catch (e) {
              print("Error refreshing Participant Tab: $e");
            }
          }

          // Toast แจ้งเตือนการเช็คอิน (Optional)
          if (type == "CHECKIN_SUCCESS" && data is List && data.length >= 2) {
            // _showTopToast("Checked-in: ${data[1]} ✅");
          }
        }
      });
    }
  }

  void _showTopToast(String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -100.0, end: 0.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_active,
                        color: Color(0xFFFFD700),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          message,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () => overlayEntry.remove());
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // กด Tab เดิมซ้ำ เพื่อ Manual Refresh
    if (index == 0 && _manageKey.currentState != null) {
      (_manageKey.currentState as dynamic).refreshData();
    } else if (index == 1 && _participantKey.currentState != null) {
      (_participantKey.currentState as dynamic).refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF4A80FF);

    final List<Widget> widgetOptions = [
      // ส่ง Key เข้าไปให้หน้าลูก
      ActivityManagementScreen(key: _manageKey),
      ActivitiesParticipantsListScreen(key: _participantKey),
    ];

    return Scaffold(
      backgroundColor: organizerBg,
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
              horizontal: 40.0,
              vertical: 10.0,
            ),
            child: SalomonBottomBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              duration: const Duration(milliseconds: 400),
              items: [
                SalomonBottomBarItem(
                  icon: const Icon(Icons.manage_accounts_outlined),
                  activeIcon: const Icon(Icons.manage_accounts),
                  title: Text(
                    "Manage",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  selectedColor: primaryColor,
                ),
                SalomonBottomBarItem(
                  icon: const Icon(Icons.group_outlined),
                  activeIcon: const Icon(Icons.group),
                  title: Text(
                    "Participants",
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
