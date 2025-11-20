import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
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
    const Color primaryColor = Color(0xFF4A80FF);

    return Scaffold(
      backgroundColor: organizerBg,
      body: IndexedStack(index: _selectedIndex, children: _widgetOptions),
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
        // [UPDATED] ใช้ SafeArea เพื่อกัน Home Indicator ทับปุ่ม
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
                  icon: const Icon(Icons.manage_accounts),
                  activeIcon: const Icon(Icons.manage_accounts),
                  title: Text(
                    "Management",
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
