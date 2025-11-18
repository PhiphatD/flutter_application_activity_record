import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  // รายการของ 4 หน้าสำหรับ organizer
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
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.manage_search),
            activeIcon: Icon(Icons.manage_accounts),
            label: 'Management',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_outlined),
            activeIcon: Icon(Icons.group),
            label: 'Participants',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.poppins(),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
