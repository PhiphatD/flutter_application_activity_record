import 'package:flutter/material.dart';
import 'screens/onboarding/splash_screen.dart'; // <-- import หน้านี้

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grow Perks',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Kanit',
        fontFamilyFallback: ['Poppins'],
      ),
      // ตั้งค่าหน้าแรกให้เป็น SplashScreen
      home: const SplashScreen(),
    );
  }
}
