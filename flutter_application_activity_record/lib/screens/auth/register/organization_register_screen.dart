import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../login_screen.dart';
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

  // --- Controllers for Company Info ---
  final _companyNameController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _addressController = TextEditingController();

  // [NEW] Controller สำหรับ Business Type กรณีเลือก Other
  final _customBusinessTypeController = TextEditingController();
  String? _selectedBusinessType;

  // --- Controllers for Admin Info ---
  // [NEW] Controller สำหรับ Title กรณีเลือก Other
  final _customAdminTitleController = TextEditingController();
  String? _selectedAdminTitle;

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
    'Other', // ต้องมีตัวเลือกนี้
  ];

  final List<String> _nameTitles = [
    'Mr.',
    'Mrs.',
    'Ms.',
    'Dr.',
    'Prof.',
    'Other', // ต้องมีตัวเลือกนี้
  ];

  // *** API URL: ใช้ 10.0.2.2:8000 สำหรับ Emulator ***
  final String apiUrl = "http://10.0.2.2:8000";

  @override
  void dispose() {
    _companyNameController.dispose();
    _taxIdController.dispose();
    _addressController.dispose();
    _customBusinessTypeController.dispose(); // [NEW]
    _customAdminTitleController.dispose(); // [NEW]
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _registerOrganization() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('รหัสผ่านไม่ตรงกัน')));
      return;
    }
    _showConfirmationDialog();
  }

  Future<void> _showConfirmationDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Text(
                        'Confirm',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF070707),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your organization account will be created upon confirmation.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF808080),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(130, 40),
                          side: const BorderSide(
                            color: Color(0xFF808080),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF808080),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _performRegistration();
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(130, 40),
                          backgroundColor: const Color(0xFF222222),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: Text(
                          'Confirm',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
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

  Future<void> _performRegistration() async {
    setState(() => _isLoading = true);

    // [NEW] Logic การเลือกค่าที่จะส่ง (ถ้าเลือก Other ให้เอาจากช่อง Custom)
    String finalBusinessType = (_selectedBusinessType == 'Other')
        ? _customBusinessTypeController.text.trim()
        : (_selectedBusinessType ?? 'Other');

    String finalAdminTitle = (_selectedAdminTitle == 'Other')
        ? _customAdminTitleController.text.trim()
        : (_selectedAdminTitle ?? 'Mr.');

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/register_organization'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          // Company Info
          'companyName': _companyNameController.text,
          'taxId': _taxIdController.text,
          'address': _addressController.text,
          'businessType': finalBusinessType, // ใช้ค่าที่คำนวณแล้ว
          // Admin Info
          'adminTitle': finalAdminTitle, // ใช้ค่าที่คำนวณแล้ว
          'adminFullName': _fullNameController.text,
          'adminEmail': _emailController.text,
          'adminPhone': _phoneController.text,
          'adminPassword': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const RegistrationSuccessfulScreen(),
            ),
            (route) => false,
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        String errorMessage = errorData['detail'] ?? 'Registration failed';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Registration error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cannot connect to server')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                // --- Section 1: Company Information ---
                _buildSectionTitle('Company Information'),

                _buildTextField(
                  controller: _companyNameController,
                  label: 'Company Name *',
                  hint: 'Your Company Name',
                  validator: _validateRequired,
                ),

                _buildTextField(
                  controller: _taxIdController,
                  label: 'Tax ID / Registration No. *',
                  hint: 'Tax ID',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Tax ID is required';
                    if (value.length != 13) return 'Tax ID must be 13 digits';
                    return null;
                  },
                ),

                // Business Type Dropdown
                _buildDropdownField(
                  label: 'Business Type',
                  hint: 'Select Type',
                  value: _selectedBusinessType,
                  items: _businessTypes,
                  onChanged: (value) =>
                      setState(() => _selectedBusinessType = value),
                  prefixIcon: Icons.business,
                ),

                // [NEW] ช่องกรอก Business Type เอง ถ้าเลือก Other
                if (_selectedBusinessType == 'Other')
                  _buildTextField(
                    controller: _customBusinessTypeController,
                    label: 'Please specify Business Type *',
                    hint: 'e.g. Agriculture, Logistics',
                    validator: _validateRequired, // บังคับกรอกถ้าเลือก Other
                  ),

                _buildTextField(
                  controller: _addressController,
                  label: 'Company Address *',
                  hint: 'Headquarters Address',
                  maxLines: 3,
                  validator: _validateRequired,
                ),

                const SizedBox(height: 24),

                // --- Section 2: Administrator Account ---
                _buildSectionTitle('Administrator Account'),

                // Title Dropdown
                _buildDropdownField(
                  label: 'Title',
                  hint: 'Select Title',
                  value: _selectedAdminTitle,
                  items: _nameTitles,
                  onChanged: (value) =>
                      setState(() => _selectedAdminTitle = value),
                  prefixIcon: Icons.person_outline,
                ),

                // [NEW] ช่องกรอก Title เอง ถ้าเลือก Other
                if (_selectedAdminTitle == 'Other')
                  _buildTextField(
                    controller: _customAdminTitleController,
                    label: 'Please specify Title *',
                    hint: 'e.g. Gen.',
                    validator: _validateRequired, // บังคับกรอกถ้าเลือก Other
                  ),

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

                // --- Submit Button ---
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _registerOrganization,
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold),
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
    int maxLines = 1,
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
            maxLines: maxLines,
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
