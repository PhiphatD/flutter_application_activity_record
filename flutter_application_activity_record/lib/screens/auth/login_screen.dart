import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// *** 1. Import หน้า Register ***
import 'register/organization_register_screen.dart';
// *** 2. Import หน้า Forgot Password ***
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

  // --- 2. แก้ไขเมธอด _login() ---
  void _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text;
      final password = _passwordController.text;
      String userRole = await _mockLoginAndGetRole(email, password);

      _navigateToUserMainScreen(userRole);
      // ไม่ต้อง setState หยุดโหลด เพราะจะย้ายไปหน้าใหม่แล้ว
    } catch (e) {
      print("Login error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อีเมลหรือรหัสผ่านไม่ถูกต้อง')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- 3. เพิ่มฟังก์ชันจำลอง API ---
  Future<String> _mockLoginAndGetRole(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final users = <String, Map<String, String>>{
      'employee@company.com': {'password': '123456', 'role': 'employee'},
      'organizer@company.com': {'password': '123456', 'role': 'organizer'},
    };
    final u = users[email.trim().toLowerCase()];
    if (u == null) throw Exception('user not found');
    if (u['password'] != password) throw Exception('invalid password');
    return u['role']!;
  }

  // --- 4. เพิ่มฟังก์ชันนำทาง ---
  void _navigateToUserMainScreen(String role) {
    Widget destinationScreen;

    switch (role.toLowerCase()) {
      case 'admin':
        // destinationScreen = const AdminMainScreen(); // Uncomment เมื่อมีหน้า Admin
        destinationScreen =
            const OrganizerMainScreen(); // ใช้หน้า Employee แทนชั่วคราว
        print('Login as: Admin');
        break;
      case 'organizer':
        // destinationScreen = const OrganizerMainScreen(); // Uncomment เมื่อมีหน้า Organizer
        destinationScreen =
            const OrganizerMainScreen(); // ใช้หน้า Employee แทนชั่วคราว
        print('Login as: Organizer');
        break;
      case 'employee':
      default:
        destinationScreen = const EmployeeMainScreen();
        print('Login as: Employee');
        break;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => destinationScreen),
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
