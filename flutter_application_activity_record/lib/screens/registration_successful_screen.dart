import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart'; // <-- 1. Import Lottie
import 'login_screen.dart';

class RegistrationSuccessfulScreen extends StatefulWidget {
  const RegistrationSuccessfulScreen({Key? key}) : super(key: key);

  @override
  _RegistrationSuccessfulScreenState createState() =>
      _RegistrationSuccessfulScreenState();
}

class _RegistrationSuccessfulScreenState
    extends State<RegistrationSuccessfulScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToLogin();
  }

  void _navigateToLogin() {
    // หน่วงเวลา 3 วินาที (เผื่อให้ Animation เล่นจบ)
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        // ไปหน้า Login และลบทุกหน้าก่อนหน้าออก
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- 2. นี่คือส่วนที่เปลี่ยน ---
            // โหลด Animation จากไฟล์ .json ที่เราเพิ่มไว้
            Lottie.asset(
              'assets/animations/Success.json', // <-- แก้ชื่อไฟล์ตรงนี้ถ้าไม่ตรงกัน
              width: 200,
              height: 200,
              repeat: false, // เล่นแค่ครั้งเดียว
            ),
            // (คุณสามารถลบ Text 'Registration Successful' ออกไปได้เลย
            // หรือจะเก็บไว้ใต้ Animation ก็ได้ครับ)
          ],
        ),
      ),
    );
  }
}
