import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart'; // <-- 1. Import google_fonts
import 'login_screen.dart';
import 'package:lottie/lottie.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // <-- 2. ตั้งพื้นหลังเป็นสีขาว
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  // Page 1: New design from Figma
                  _buildInfoPage(
                    lottiePath: 'assets/animations/Welcome.json',
                    title: 'ยิ่งร่วม ยิ่งได้\nแต้มพุ่ง รางวัลปัง!!',
                    description:
                        'แพลตฟอร์มเพื่อการเรียนรู้และเติบโต. เข้าร่วมกิจกรรม, สะสมแต้ม, \nแลกรางวัล เพื่อศักยภาพที่ไร้ขีดจำกัดของคุณ',
                    imageHeight: 380,
                  ),
                  // Page 2
                  _buildInfoPage(
                    lottiePath: 'assets/animations/Business team.json',
                    title: 'กิจกรรมดี ๆ\nเพื่อทีมที่แข็งแรง',
                    description:
                        'ค้นหากิจกรรมที่น่าสนใจภายในองค์กร และเข้าร่วมเพื่อเก็บแต้มและพัฒนาความสัมพันธ์ในทีม',
                    imageHeight: 380,
                  ),
                  // Page 3
                  _buildInfoPage(
                    lottiePath: 'assets/animations/Businessman flies up with rocket.json',
                    title: 'เปลี่ยนกิจกรรม\nให้เป็นโอกาส',
                    description:
                        'ทุกกิจกรรมที่คุณเข้าร่วมคือการเปิดโอกาสใหม่ๆ ให้กับตัวเอง สะสมแต้มเพื่อแลกของรางวัลสุดพิเศษ!',
                    imageHeight: 380,
                  ),
                ],
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  // Widget for creating content on each page
  Widget _buildInfoPage({
    required String lottiePath,
    required String title,
    required String description,
    double imageHeight = 250,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(lottiePath, height: imageHeight, fit: BoxFit.contain),
          const SizedBox(height: 24),
          // Move page indicator to be under the image (ตามภาพ Figma)
          SmoothPageIndicator(
            controller: _pageController,
            count: 3,
            effect: WormEffect(
              dotHeight: 8,
              dotWidth: 8,
              activeDotColor: Colors.black, // #000000
              dotColor: Colors.grey[300]!,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.mulish(
              fontSize: 35,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.mulish(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // Widget สำหรับส่วนควบคุมด้านล่าง
  Widget _buildBottomControls() {
    bool isLastPage = _currentPage == 2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      height: 120,
      child: Column(
        children: [
          const Spacer(),

          // 2. Buttons
          isLastPage
              // (หน้า Info 3) - ปุ่ม START
              ? SizedBox(
                  width: double.infinity,
                  child: _buildActionButton(
                    text: 'START',
                    isPrimary: true, // Style สีดำ
                    onTap: _onDone,
                  ),
                )
              // (หน้า Info 1 & 2) - ปุ่ม SKIP และ NEXT
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildActionButton(
                      text: 'SKIP',
                      isPrimary: false, // Style สีขาว
                      onTap: _onDone,
                    ),
                    _buildActionButton(
                      text: 'NEXT',
                      isPrimary: true, // Style สีดำ
                      onTap: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      },
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  // <-- 6. สร้าง Widget ใหม่สำหรับปุ่ม (ตามดีไซน์ใน CSS)
  /// สร้างปุ่ม Action (SKIP, NEXT, START)
  /// `isPrimary = true` จะเป็นปุ่มสีดำ (NEXT/START)
  /// `isPrimary = false` จะเป็นปุ่มสีขาว (SKIP)
  Widget _buildActionButton({
    required String text,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    final backgroundColor = isPrimary ? Colors.black : Colors.white;
    final textColor = isPrimary ? Colors.white : Colors.black;

    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 8, // สร้างเงา (ตาม Figma shadow ที่เด่นขึ้นเล็กน้อย)
        shadowColor: Colors.black.withOpacity(0.15),
        minimumSize: const Size(118, 68), // ขนาดตาม CSS (w: 118, h: 68)
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50), // border-radius: 50px
        ),
        // เพิ่มเส้นขอบบางสำหรับปุ่ม SKIP ให้คล้าย Figma
        side: isPrimary
            ? BorderSide.none
            : const BorderSide(color: Colors.black, width: 1),
      ),
      child: Text(
        text,
        // <-- 7. อัปเดต Font ปุ่มตาม CSS
        style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w500),
      ),
    );
  }
}
