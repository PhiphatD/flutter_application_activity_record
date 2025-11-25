import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';

import 'onboarding_screen.dart';
import '../auth/login_screen.dart';
import '../organizer_screens/main/organizer_main_screen.dart';
import '../employee_screens/main/employee_main_screen.dart';
// [IMPORT] อย่าลืม Import หน้า Admin ที่สร้างไว้ครับ
import '../admin_screens/admin_main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();

    final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final String? role = prefs.getString('role');

    if (isLoggedIn && role != null) {
      Widget destination;

      // [FIXED] แยก Role ให้ชัดเจน
      final cleanRole = role.toLowerCase();
      if (cleanRole == 'admin') {
        destination = const AdminMainScreen(); // ไปหน้า Admin
      } else if (cleanRole == 'organizer') {
        destination = const OrganizerMainScreen(); // ไปหน้า Organizer
      } else {
        // Employee หรืออื่นๆ ให้ไปหน้า Employee
        destination = const EmployeeMainScreen();
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => destination),
      );
    } else {
      if (hasSeenOnboarding) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final animSize = size.width * 0.5;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Lottie.asset(
          'assets/animations/Material wave loading.json',
          width: animSize,
          height: animSize,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
