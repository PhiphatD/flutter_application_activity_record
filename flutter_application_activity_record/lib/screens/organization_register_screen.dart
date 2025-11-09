import 'package:flutter/material.dart';
// *** 1. Import หน้า Login และ Google Fonts ***
import 'login_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'registration_successful_screen.dart';

class OrganizationRegisterScreen extends StatefulWidget {
  const OrganizationRegisterScreen({Key? key}) : super(key: key);

  @override
  _OrganizationRegisterScreenState createState() =>
      _OrganizationRegisterScreenState();
}

class _OrganizationRegisterScreenState
    extends State<OrganizationRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _companyNameController = TextEditingController();
  String? _businessType;
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  final List<String> _businessTypes = [
    'Technology',
    'Finance & Insurance',
    'Healthcare',
    'Retail',
    'Manufacturing',
    'Services & Consulting',
    'Education',
    'Real Estate & Construction',
    'Non-Profit',
    'Other',
  ];
  String? _selectedBusinessType;

  @override
  void dispose() {
    _companyNameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // *** 2. แก้ไขฟังก์ชันนี้ ให้เรียก Dialog ***
  Future<void> _registerOrganization() async {
    // 1. ตรวจสอบความถูกต้องของ Form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 2. ตรวจสอบรหัสผ่านว่าตรงกัน
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('รหัสผ่านไม่ตรงกัน')));
      return;
    }

    // 3. ถ้าทุกอย่างถูกต้อง ให้แสดง Dialog
    _showConfirmationDialog();
  }

  // *** 3. เพิ่มฟังก์ชันสำหรับสร้าง Dialog ตามดีไซน์ ***
  Future<void> _showConfirmationDialog() async {
    // (ใช้ Font 'Inter' ตาม CSS ที่คุณให้มา)
    showDialog(
      context: context,
      barrierDismissible: false, // ไม่ให้ปิด dialog โดยการแตะข้างนอก
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0), // border-radius: 16px
          ),
          child: Container(
            width: 300, // width: 300px
            padding: const EdgeInsets.all(16.0), // padding: 16px
            child: Column(
              mainAxisSize: MainAxisSize.min, // ให้ Column สูงเท่าที่จำเป็น
              children: [
                // Content
                Padding(
                  padding: const EdgeInsets.all(8.0), // padding: 8px
                  child: Column(
                    children: [
                      // Title
                      Text(
                        'Confirm',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800, // 800 weight
                          color: const Color(0xFF070707),
                        ),
                      ),
                      const SizedBox(height: 8), // gap: 8px
                      // Description
                      Text(
                        'Your organization account will be created upon confirmation.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400, // 400 weight
                          color: const Color(0xFF808080), // #808080
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 20,
                ), // gap: 20px (ระหว่าง content กับ actions)
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Action 1 (Cancel)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext); // ปิด Dialog
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(130, 40), // w:130, h:40
                          side: const BorderSide(
                            color: Color(0xFF808080), // #808080
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0), // 12px
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600, // 600 weight
                            color: const Color(0xFF808080),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8), // gap: 8px
                    // Action 2 (Confirm)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext); // ปิด Dialog
                          _performRegistration(); // << เรียก Logic การสมัครจริง
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(130, 40), // w:130, h:40
                          backgroundColor: const Color(0xFF222222), // #222222
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0), // 12px
                          ),
                        ),
                        child: Text(
                          'Confirm',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800, // 800 weight
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // *** 4. สร้างฟังก์ชันใหม่สำหรับ Logic การสมัคร (ย้ายมาจาก _registerOrganization) ***
  Future<void> _performRegistration() async {
    setState(() {
      _isLoading = true;
    });

    // --- TODO: เชื่อมต่อ API/Backend ที่นี่ ---
    Map<String, dynamic> registrationData = {
      'companyName': _companyNameController.text,
      'businessType': _businessType,
      'adminFullName': _fullNameController.text,
      'adminEmail': _emailController.text,
      'adminPhone': _phoneController.text,
      'adminPassword': _passwordController.text,
    };

    print("Sending registration data:");
    print(registrationData);

    // 4. จำลองการเชื่อมต่อ
    await Future.delayed(const Duration(seconds: 2));

    // 5. เมื่อเสร็จสิ้น (สมมติว่าสำเร็จ)
    setState(() {
      _isLoading = false;
    });

    // *** 3. เปลี่ยนปลายทาง (Destination) ***
    if (mounted) {
      // ลบ SnackBar ออก และเปลี่ยนไปหน้า Success
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          // *** ไปที่หน้า RegistrationSuccessfulScreen ***
          builder: (context) => const RegistrationSuccessfulScreen(),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (ส่วน Build UI ที่เหลือเหมือนเดิมทั้งหมด) ...
    // ... (ไม่จำเป็นต้องแก้ไขส่วน UI) ...
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: const BackButton(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Company Information'),
                _buildTextField(
                  controller: _companyNameController,
                  label: 'Company Name *',
                  hint: 'Your Company Name',
                  validator: _validateRequired,
                ),
                _buildDropdownField(
                  label: 'Business Type',
                  hint: 'Optional',
                  value: _businessType,
                  items: _businessTypes,
                  onChanged: (value) {
                    setState(() {
                      _businessType = value;
                    });
                  },
                  prefixIcon: Icons.business,
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('Administrator Account'),
                _buildTextField(
                  controller: _fullNameController,
                  label: 'Full Name *',
                  hint: 'Your Full Name',
                  validator: _validateRequired,
                ),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email Address *',
                  hint: 'Your Email Address',
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone Number *',
                  hint: 'Your Phone Number',
                  keyboardType: TextInputType.phone,
                  validator: _validateRequired,
                ),
                _buildTextField(
                  controller: _passwordController,
                  label: 'Password *',
                  obscureText: true,
                  validator: _validatePassword,
                ),
                _buildTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password *',
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed:
                            _registerOrganization, // <- เรียกฟังก์ชันที่อัปเดตแล้ว
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Create Your Organization Account',
                          style: GoogleFonts.inter(
                            // ใช้อะไรก็ได้ แต่ Inter ดูเข้ากันดี
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                const SizedBox(height: 20),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text("Already have an Organization Account? "),
                      GestureDetector(
                        onTap: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          }
                        },
                        child: Text(
                          'Sign in',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // (Widgets _buildSectionTitle, _buildTextField, _buildDropdownField, และ Validators ทั้งหมดเหมือนเดิม)

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              // ใช้อะไรก็ได้ แต่ Inter ดูเข้ากันดี
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Divider(color: Colors.grey[300], thickness: 1),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required void Function(String?)? onChanged,
    IconData? prefixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: value,
            isExpanded: true,
            isDense: true,
            menuMaxHeight: 280,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.grey[700],
            ),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF222222),
            ),
            dropdownColor: Colors.white,
            items: items.map((String item) {
              return DropdownMenuItem<String>(value: item, child: Text(item));
            }).toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, color: Colors.grey[600])
                  : null,
              hintText: hint,
              hintStyle: GoogleFonts.inter(color: Colors.grey[500]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF222222),
                  width: 1.6,
                ),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _validateRequired(String? value) {
    if (value == null || value.isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }
}
