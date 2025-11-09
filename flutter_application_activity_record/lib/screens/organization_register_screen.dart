import 'package:flutter/material.dart';
// *** 1. Import หน้า Login ***
import 'login_screen.dart';

class OrganizationRegisterScreen extends StatefulWidget {
  const OrganizationRegisterScreen({Key? key}) : super(key: key);

  @override
  _OrganizationRegisterScreenState createState() =>
      _OrganizationRegisterScreenState();
}

class _OrganizationRegisterScreenState
    extends State<OrganizationRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // (Controllers ต่างๆ เหมือนเดิม)
  final _companyNameController = TextEditingController();
  String? _businessType;
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  final List<String> _businessTypes = ['Technology', 'Retail', 'Education', 'Other'];

  @override
  void dispose() {
    // (dispose เหมือนเดิม)
    _companyNameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _registerOrganization() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('รหัสผ่านไม่ตรงกัน')),
      );
      return;
    }

    setState(() { _isLoading = true; });

    // (ส่วน TODO: เชื่อมต่อ API/Backend เหมือนเดิม)
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
    await Future.delayed(const Duration(seconds: 2));

    setState(() { _isLoading = false; });
    
    // *** 2. แก้ไข TODO: เมื่อสมัครเสร็จ ให้พากลับไปหน้า Login ***
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('สร้างบัญชีองค์กรสำเร็จ! กรุณาเข้าสู่ระบบ')),
      );
      // ไปหน้า Login และลบหน้านี้ (Register) ออกจาก Stack
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false, // ลบทุกหน้าที่ผ่านมา
      );
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
                // (UI ส่วนบนทั้งหมดเหมือนเดิม)
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
                    setState(() { _businessType = value; });
                  },
                ),
                const SizedBox(height: 24),
                
                _buildSectionTitle('Administrator Account'),
                // (Text Fields ต่างๆ เหมือนเดิม)
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
                        onPressed: _registerOrganization,
                        // (Style เหมือนเดิม)
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Create Your Organization Account',
                          style: TextStyle(fontSize: 16, color: Colors.white),
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
                          // *** 3. แก้ไข TODO: ทำให้ปุ่ม Sign in กดกลับไปหน้า Login ได้ ***
                          // ถ้าหน้านี้ถูก Push มา (ซึ่งควรจะเป็น) pop() จะกลับไปหน้า Login
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            // กรณีฉุกเฉิน ถ้ากลับไม่ได้ ให้ Push ไป Login แทน
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
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

  // (Widgets ด้านล่าง _buildSectionTitle, _buildTextField, 
  // _buildDropdownField, และ Validators ทั้งหมดเหมือนเดิม)
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: value,
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
            onChanged: onChanged,
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