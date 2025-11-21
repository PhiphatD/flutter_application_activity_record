import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart'; // ใช้ Package เดียวกัน
import 'package:flutter_application_activity_record/theme/app_colors.dart';

import '../activities/activity_feed_screen.dart';
import '../rewards/reward_screen.dart';
import '../activities/todo_screen.dart';

class EmployeeMainScreen extends StatefulWidget {
  const EmployeeMainScreen({super.key});

  @override
  State<EmployeeMainScreen> createState() => _EmployeeMainScreenState();
}

class _EmployeeMainScreenState extends State<EmployeeMainScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Theme สีฟ้าสำหรับ Employee
    const Color primaryColor = Color(0xFF4A80FF);

    final List<Widget> widgetOptions = <Widget>[
      ActivityFeedScreen(onGoToTodo: () => _onItemTapped(1)),
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
