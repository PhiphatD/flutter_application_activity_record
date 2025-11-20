import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../login_screen.dart';
import 'registration_successful_screen.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';

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
  final _taxIdController = TextEditingController();
  final _addressController = TextEditingController();
  final _customBusinessTypeController = TextEditingController();
  String? _selectedBusinessType;

  final _customAdminTitleController = TextEditingController();
  String? _selectedAdminTitle;

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _adminStartDateController = TextEditingController();

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

  final List<String> _nameTitles = [
    'Mr.',
    'Mrs.',
    'Ms.',
    'Dr.',
    'Prof.',
    'Other',
  ];

  final String apiUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";

  @override
  void dispose() {
    _companyNameController.dispose();
    _taxIdController.dispose();
    _addressController.dispose();
    _customBusinessTypeController.dispose();
    _customAdminTitleController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _adminStartDateController.dispose();
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
            width: 320, // จำกัดความกว้าง Dialog ไม่ให้เต็มจอเกินไป
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Confirm Registration',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Create new organization account?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _performRegistration();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Confirm'),
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
          'companyName': _companyNameController.text,
          'taxId': _taxIdController.text,
          'address': _addressController.text,
          'businessType': finalBusinessType,
          'adminTitle': finalAdminTitle,
          'adminFullName': _fullNameController.text,
          'adminEmail': _emailController.text,
          'adminPhone': _phoneController.text,
          'adminPassword': _passwordController.text,
          'adminStartDate': _adminStartDateController.text.isNotEmpty
              ? _adminStartDateController.text
              : DateTime.now().toString().substring(0, 10),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorData['detail'] ?? 'Registration failed')),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cannot connect to server')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // [UPDATED] Center Content for large screens
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: const BackButton(color: Colors.black),
        title: Text(
          "Register Organization",
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 600,
            ), // จำกัดความกว้างไม่ให้เกิน 600px (เหมือน Web/iPad App)
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
                    _buildTextField(
                      controller: _taxIdController,
                      label: 'Tax ID / Registration No. *',
                      hint: 'Tax ID',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Tax ID is required';
                        if (value.length != 13)
                          return 'Tax ID must be 13 digits';
                        return null;
                      },
                    ),
                    _buildDropdownField(
                      label: 'Business Type',
                      hint: 'Select Type',
                      value: _selectedBusinessType,
                      items: _businessTypes,
                      onChanged: (value) =>
                          setState(() => _selectedBusinessType = value),
                      prefixIcon: Icons.business,
                    ),
                    if (_selectedBusinessType == 'Other')
                      _buildTextField(
                        controller: _customBusinessTypeController,
                        label: 'Please specify Business Type *',
                        hint: 'e.g. Agriculture',
                        validator: _validateRequired,
                      ),
                    _buildTextField(
                      controller: _addressController,
                      label: 'Company Address *',
                      hint: 'Headquarters Address',
                      maxLines: 3,
                      validator: _validateRequired,
                    ),
                    const SizedBox(height: 32),

                    _buildSectionTitle('Administrator Account'),
                    _buildDropdownField(
                      label: 'Title',
                      hint: 'Select Title',
                      value: _selectedAdminTitle,
                      items: _nameTitles,
                      onChanged: (value) =>
                          setState(() => _selectedAdminTitle = value),
                      prefixIcon: Icons.person_outline,
                    ),
                    if (_selectedAdminTitle == 'Other')
                      _buildTextField(
                        controller: _customAdminTitleController,
                        label: 'Please specify Title *',
                        hint: 'e.g. Gen.',
                        validator: _validateRequired,
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

                    // Date Picker Field
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Start Date",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _adminStartDateController,
                            readOnly: true,
                            onTap: _openStartDatePicker,
                            validator: _validateRequired,
                            decoration: InputDecoration(
                              hintText: 'Select Start Date',
                              prefixIcon: Icon(
                                Icons.calendar_today,
                                color: Colors.grey[600],
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                          ),
                        ],
                      ),
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
                        if (value == null || value.isEmpty)
                          return 'Please confirm password';
                        if (value != _passwordController.text)
                          return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 40),

                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _registerOrganization,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 2,
                              ),
                              child: Text(
                                'Create Account',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ... (Helper Methods เหมือนเดิม) ...
  void _openStartDatePicker() async {
    // ... code เดิม
    final initialDate = _adminStartDateController.text.isNotEmpty
        ? DateTime.parse(_adminStartDateController.text)
        : DateTime.now();
    List<DateTime?> results = [initialDate];
    final values = await showModalBottomSheet<List<DateTime?>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height:
            MediaQuery.of(context).size.height * 0.6, // จำกัดความสูง Calendar
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ... (ส่วน Header)
            Expanded(
              child: CalendarDatePicker2(
                config: CalendarDatePicker2Config(
                  calendarType: CalendarDatePicker2Type.single,
                ),
                value: results,
                onValueChanged: (dates) => results = dates,
              ),
            ),
            // ... (ส่วนปุ่ม Confirm)
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, results),
                child: const Text("Confirm"),
              ),
            ),
          ],
        ),
      ),
    );

    if (values != null && values.isNotEmpty && values[0] != null) {
      final d = values[0]!;
      setState(() {
        _adminStartDateController.text =
            "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
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
            items: items.map((String item) {
              return DropdownMenuItem<String>(value: item, child: Text(item));
            }).toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
              hintText: hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ],
      ),
    );
  }

  String? _validateRequired(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    if (!value.contains('@')) return 'Invalid Email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.length < 6) return 'Min 6 chars';
    return null;
  }
}
