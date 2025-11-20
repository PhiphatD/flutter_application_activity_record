import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../login_screen.dart';

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
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
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
    // [UPDATED] Responsive Size
    final size = MediaQuery.of(context).size;
    final animSize = size.width * 0.6; // 60% ของความกว้างจอ

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/Success.json',
              width: animSize,
              height: animSize,
              repeat: false,
            ),
          ],
        ),
      ),
    );
  }
}
