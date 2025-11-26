import 'package:flutter/material.dart';
import 'package:flutter_application_activity_record/screens/admin_screens/admin_dashboard_screen.dart';
import 'package:flutter_application_activity_record/screens/admin_screens/admin_profile_screen.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:flutter_application_activity_record/theme/app_colors.dart';
import 'employees/admin_employee_list_screen.dart';
import 'rewards/admin_reward_management_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _selectedIndex = 0;

  final GlobalKey<AdminRewardManagementScreenState> _rewardScreenKey =
      GlobalKey();

  void _switchTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // [2] ฟังก์ชันพิเศษสำหรับ Deep Link ไปที่ Requests Tab
  void _navigateToPendingRequests() {
    setState(() {
      _selectedIndex = 2; // 1. สลับไปหน้า Rewards (Index 2)
    });

    // 2. สั่งให้หน้า Rewards สลับไป Tab "Requests" (ต้องรอเฟรมถัดไปนิดนึงเพื่อให้ Widget สร้างเสร็จ)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rewardScreenKey.currentState?.switchToRequestsTab();
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF4A80FF);

    final List<Widget> screens = [
      // [3] ส่ง Callback ไปให้ Dashboard
      AdminDashboardScreen(
        onSwitchTab: _switchTab,
        onGoToRequests: _navigateToPendingRequests,
      ),
      const AdminEmployeeListScreen(),
      // [4] ผูก Key ใส่หน้า Rewards
      AdminRewardManagementScreen(key: _rewardScreenKey),
      const AdminProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: organizerBg, // ใช้ Theme เดียวกับ Organizer
      body: IndexedStack(index: _selectedIndex, children: screens),
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
              onTap: (i) => setState(() => _selectedIndex = i),
              items: [
                SalomonBottomBarItem(
                  icon: const Icon(Icons.dashboard_outlined),
                  activeIcon: const Icon(Icons.dashboard),
                  title: Text(
                    "Overview",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  selectedColor: primaryColor,
                ),
                SalomonBottomBarItem(
                  icon: const Icon(Icons.people_outline),
                  activeIcon: const Icon(Icons.people),
                  title: Text(
                    "People",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  selectedColor: primaryColor,
                ),
                SalomonBottomBarItem(
                  icon: const Icon(Icons.card_giftcard_outlined),
                  activeIcon: const Icon(Icons.card_giftcard),
                  title: Text(
                    "Rewards",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  selectedColor: primaryColor,
                ),
                SalomonBottomBarItem(
                  icon: const Icon(Icons.person_outline),
                  activeIcon: const Icon(Icons.person),
                  title: Text(
                    "Profile",
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
