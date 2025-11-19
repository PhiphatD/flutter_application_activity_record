import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; // [1] Import เพิ่ม

import 'register/organization_register_screen.dart';
import 'password/forgot_password_screen.dart';
import '../employee_screens/main/employee_main_screen.dart';
import '../organizer_screens/main/organizer_main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // *** API URL: ใช้ 10.0.2.2:8000 สำหรับ Android Emulator ***
  // ถ้าใช้ iOS Simulator ใช้ http://localhost:8000
  // ถ้าใช้เครื่องจริง ใช้ IP เครื่องคอมฯ เช่น http://192.168.1.x:8000
  final String apiUrl = "http://10.0.2.2:8000";

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": _emailController.text
              .trim(), // trim() เพื่อตัดช่องว่างหัวท้าย
          "password": _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // [2] บันทึกข้อมูลผู้ใช้ลงเครื่อง
        await _saveUserData(data);

        String role = data['role'];
        _navigateToUserMainScreen(role);
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage =
            errorData['detail'] ?? 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage)));
        }
      }
    } catch (e) {
      print("Login error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ (กรุณาเปิด Python Server)',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ฟังก์ชันบันทึกข้อมูลลง SharedPreferences
  Future<void> _saveUserData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', data['role']);
    await prefs.setString('empId', data['emp_id']);
    await prefs.setString('name', data['name']);

    // company_id อาจจะเป็น null ได้ในบางกรณี (ถ้าไม่ได้ส่งมา)
    if (data['company_id'] != null) {
      await prefs.setString('companyId', data['company_id']);
    }

    // ตั้งค่าว่า Login แล้ว (เผื่อใช้เช็คใน SplashScreen)
    await prefs.setBool('isLoggedIn', true);

    print("User data saved: ${data['name']} (${data['role']})");
  }

  void _navigateToUserMainScreen(String role) {
    Widget destinationScreen;

    // เช็ค Role (แปลงเป็นตัวเล็กเพื่อความชัวร์)
    switch (role.toLowerCase()) {
      case 'admin':
        destinationScreen = const OrganizerMainScreen();
        print('Navigate to: Organizer/Admin Screen');
        break;
      case 'organizer':
        destinationScreen = const OrganizerMainScreen();
        print('Navigate to: Organizer/Admin Screen');
        break;
      case 'employee':
      default:
        destinationScreen = const EmployeeMainScreen();
        print('Navigate to: Employee Screen');
        break;
    }

    // ใช้ pushAndRemoveUntil เพื่อไม่ให้กด Back กลับมาหน้า Login ได้
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => destinationScreen),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ... (ส่วน UI Code เหมือนเดิม ไม่ต้องแก้) ...
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 76),
                      Image.asset(
                        'assets/images/login_ellipse.png',
                        height: 200,
                        errorBuilder: (context, error, stack) =>
                            const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Log in to continue',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF9E9E9E),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          hintText: 'Your Email',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 16,
                            color: const Color(0xFFBDBDBD),
                          ),
                          prefixIcon: const Icon(Icons.email, size: 20),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE0E0E0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE0E0E0),
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty ||
                              !value.contains('@')) {
                            return 'กรุณากรอกอีเมลให้ถูกต้อง';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 16,
                            color: const Color(0xFFBDBDBD),
                          ),
                          prefixIcon: const Icon(Icons.lock, size: 20),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE0E0E0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE0E0E0),
                            ),
                          ),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'กรุณากรอกรหัสผ่าน';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ForgotPasswordScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Forgot Password?',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF424242),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF434343),
                            foregroundColor: Colors.white,
                            elevation: 1,
                            shadowColor: Colors.black.withOpacity(0.15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.0,
                                )
                              : Text(
                                  'Log In',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const OrganizationRegisterScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD9D9D9),
                            foregroundColor: Colors.black54,
                            elevation: 2,
                            shadowColor: Colors.black.withOpacity(0.15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Register Your Organization',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
