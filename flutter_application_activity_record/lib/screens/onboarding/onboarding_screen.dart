import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';

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
    // [UPDATED] ดึงขนาดจอมาคำนวณ
    final size = MediaQuery.of(context).size;
    final isSmallScreen =
        size.height < 700; // เช็คว่าจอเล็กไหม (เช่น iPhone SE)

    return Scaffold(
      backgroundColor: Colors.white,
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
                  _buildInfoPage(
                    lottiePath: 'assets/animations/Welcome.json',
                    title: 'ยิ่งร่วม ยิ่งได้\nแต้มพุ่ง รางวัลปัง!!',
                    description:
                        'แพลตฟอร์มเพื่อการเรียนรู้และเติบโต. เข้าร่วมกิจกรรม, สะสมแต้ม, \nแลกรางวัล เพื่อศักยภาพที่ไร้ขีดจำกัดของคุณ',
                    isSmallScreen: isSmallScreen,
                  ),
                  _buildInfoPage(
                    lottiePath: 'assets/animations/Business team.json',
                    title: 'กิจกรรมดี ๆ\nเพื่อทีมที่แข็งแรง',
                    description:
                        'ค้นหากิจกรรมที่น่าสนใจภายในองค์กร และเข้าร่วมเพื่อเก็บแต้มและพัฒนาความสัมพันธ์ในทีม',
                    isSmallScreen: isSmallScreen,
                  ),
                  _buildInfoPage(
                    lottiePath:
                        'assets/animations/Businessman flies up with rocket.json',
                    title: 'เปลี่ยนกิจกรรม\nให้เป็นโอกาส',
                    description:
                        'ทุกกิจกรรมที่คุณเข้าร่วมคือการเปิดโอกาสใหม่ๆ ให้กับตัวเอง สะสมแต้มเพื่อแลกของรางวัลสุดพิเศษ!',
                    isSmallScreen: isSmallScreen,
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

  Widget _buildInfoPage({
    required String lottiePath,
    required String title,
    required String description,
    required bool isSmallScreen,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          // [UPDATED] กันล้นในจอแนวนอน หรือจอเล็กมาก
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // [UPDATED] ใช้ Flexible height แทนค่าตายตัว
                  SizedBox(
                    height: constraints.maxHeight * 0.45, // 45% ของพื้นที่ที่มี
                    child: Lottie.asset(lottiePath, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 24),
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: 3,
                    effect: WormEffect(
                      dotHeight: 8,
                      dotWidth: 8,
                      activeDotColor: Colors.black,
                      dotColor: Colors.grey[300]!,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.kanit(
                      fontSize: isSmallScreen
                          ? 28
                          : 35, // [UPDATED] ปรับขนาด Font
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.kanit(
                      fontSize: isSmallScreen
                          ? 16
                          : 20, // [UPDATED] ปรับขนาด Font
                      fontWeight: FontWeight.w400,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20), // เผื่อที่ด้านล่างนิดหน่อย
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomControls() {
    bool isLastPage = _currentPage == 2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      // [UPDATED] ปรับความสูง Container ตามเนื้อหา ไม่ Fix ตายตัว
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLastPage)
            SizedBox(
              width: double.infinity,
              child: _buildActionButton(
                text: 'START',
                isPrimary: true,
                onTap: _onDone,
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildActionButton(
                  text: 'SKIP',
                  isPrimary: false,
                  onTap: _onDone,
                ),
                _buildActionButton(
                  text: 'NEXT',
                  isPrimary: true,
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
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.15),
        // [UPDATED] ปรับขนาดปุ่มให้เล็กลงนิดนึงในจอเล็ก
        minimumSize: const Size(110, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        side: isPrimary
            ? BorderSide.none
            : const BorderSide(color: Colors.black, width: 1),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }
}
