import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart'; // [1] Import Package
import 'package:flutter_application_activity_record/theme/app_colors.dart';

// Import organizer screens
import '../activities/activities_management_screen.dart';
import '../participants/participants_screen.dart';

class OrganizerMainScreen extends StatefulWidget {
  const OrganizerMainScreen({super.key});

  @override
  State<OrganizerMainScreen> createState() => _OrganizerMainScreenState();
}

class _OrganizerMainScreenState extends State<OrganizerMainScreen> {
  int _selectedIndex = 0;

  // รายการของ 4 หน้าสำหรับ organizer (ตอนนี้มี 2 หน้า)
  static const List<Widget> _widgetOptions = <Widget>[
    ActivityManagementScreen(),
    ParticipantsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // กำหนดสีหลัก (ใช้สีเดิมของ App คุณ)
    const Color primaryColor = Color(0xFF4A80FF);

    return Scaffold(
      backgroundColor: organizerBg,
      body: IndexedStack(index: _selectedIndex, children: _widgetOptions),
      // [2] เปลี่ยนจาก BottomNavigationBar เป็น SalomonBottomBar
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: SalomonBottomBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            // กำหนด Animation Duration ให้ลื่นไหล
            duration: const Duration(milliseconds: 400),

            items: [
              /// Tab 1: Management
              SalomonBottomBarItem(
                icon: const Icon(Icons.manage_accounts),
                activeIcon: const Icon(Icons.manage_accounts),
                title: Text(
                  "Management",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
                selectedColor: primaryColor,
              ),

              /// Tab 2: Participants
              SalomonBottomBarItem(
                icon: const Icon(Icons.group_outlined),
                activeIcon: const Icon(Icons.group),
                title: Text(
                  "Participants",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
                // คุณสามารถเปลี่ยนสีของ Tab นี้ให้ต่างออกไปได้ถ้าต้องการ (เช่น Colors.teal)
                // แต่ผมใส่สีเดียวกับ Primary เพื่อความคุมโทนครับ
                selectedColor: primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
