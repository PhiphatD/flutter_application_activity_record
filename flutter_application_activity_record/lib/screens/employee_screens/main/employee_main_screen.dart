import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application_activity_record/theme/app_colors.dart';

// อัปเดต import ให้เรียกจากในโฟลเดอร์เดียวกัน
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

  // รายการของ 3 หน้าที่จะสลับไปมา
  static const List<Widget> _widgetOptions = <Widget>[
    ActivityFeedScreen(), // หน้าแท็บที่ 1
    TodoScreen(), // หน้าแท็บที่ 2
    RewardScreen(), // หน้าแท็บที่ 3
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF4A80FF);

    return Scaffold(
      backgroundColor: employeeBg,
      body: IndexedStack(index: _selectedIndex, children: _widgetOptions),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view_rounded),
            label: 'Activity',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.checklist_outlined),
            activeIcon: Icon(Icons.checklist_rounded),
            label: 'To do',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_giftcard_outlined),
            activeIcon: Icon(Icons.card_giftcard_rounded),
            label: 'Reward',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.poppins(),
      ),
    );
  }
}
