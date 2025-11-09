import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    // 1. หน่วงเวลาเพื่อแสดงโลโก้ (จำลองการโหลด)
    await Future.delayed(const Duration(seconds: 3));

    // 2. ตรวจสอบค่าใน SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    // ถ้าไม่เคยมีค่านี้ (เปิดครั้งแรก) ให้ default เป็น false
    final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    // 3. เปลี่ยนหน้าจอ
    if (mounted) {
      if (hasSeenOnboarding) {
        // ถ้าเคยเห็นแล้ว -> ไปหน้า Login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        // ถ้ายังไม่เคยเห็น (ครั้งแรก) -> ไปหน้า Onboarding
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // TODO: ใส่โลโก้ "GROW PERKS" ของคุณที่นี่
            //             Image.asset('assets/images/logo.png', width: 150), // สมมติว่านี่คือโลโก้
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
