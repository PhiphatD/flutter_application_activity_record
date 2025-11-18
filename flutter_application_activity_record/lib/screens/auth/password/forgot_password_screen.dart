import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// เพิ่มบรรทัดนี้ที่โซน import ด้านบน
import 'verify_otp_screen.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0, // ไม่มีเงา
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black,
          ), // <--- ใช้ Icons.arrow_back และสีดำ
          onPressed: () => Navigator.of(context).pop(),
        ),
        // title: Text( // <--- ลบหรือคอมเมนต์ส่วนนี้ออก เพื่อไม่ให้มีข้อความตรงกลาง
        //   'Forgot Password',
        //   style: GoogleFonts.poppins(
        //     color: primaryColor,
        //     fontWeight: FontWeight.bold,
        //   ),
        // ),
        // centerTitle: true, // <--- ลบหรือคอมเมนต์ส่วนนี้ออก
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment
                  .start, // <--- เปลี่ยนเป็น start เพื่อให้ข้อความชิดซ้าย
              children: [
                const SizedBox(
                  height: 16,
                ), // ลดความสูงลงหน่อย เพราะไม่มี Title ข้างบนแล้ว
                // --- ส่วนหัวข้อ ---
                Text(
                  'Forgot Password', // <--- ย้ายข้อความ "Forgot Password" มาเป็นหัวข้อหลักด้านล่าง AppBar
                  style: GoogleFonts.poppins(
                    fontSize: 28, // ปรับขนาดให้ใหญ่ขึ้น
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Enter the email associated with your account and we\'ll send a code to reset your password.',
                  textAlign: TextAlign.left, // <--- เปลี่ยนเป็น left
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 40),

                // --- ช่องกรอกอีเมล (สไตล์เดียวกับหน้า Login) ---
                TextFormField(
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your work email',
                    prefixIcon: Icon(Icons.email_outlined, color: primaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide(color: primaryColor, width: 2.0),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // --- ปุ่ม Send Code (สไตล์เดียวกับหน้า Login) ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VerifyOtpScreen(),
                        ),
                      );
                      // หลังกดปุ่มนี้ ให้ Navigator.push ไป หน้า VerifyOtpScreen
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF434343),
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    child: Text(
                      'Send Code',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // --- ปุ่มกลับไปหน้า Login (สไตล์เดียวกับหน้า Login) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Remember password?',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // กลับไปหน้า Login
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Sign In',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
