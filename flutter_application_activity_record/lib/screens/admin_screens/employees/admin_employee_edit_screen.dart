import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../services/admin_service.dart';

class AdminEmployeeEditScreen extends StatefulWidget {
  final Map<String, dynamic> employeeData;
  const AdminEmployeeEditScreen({super.key, required this.employeeData});

  @override
  State<AdminEmployeeEditScreen> createState() => _AdminEmployeeEditScreenState();
}

class _AdminEmployeeEditScreenState extends State<AdminEmployeeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final AdminService _service = AdminService();
  bool _isSaving = false;

  // Controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _titleCtrl = TextEditingController(); // Mr/Ms (Optional dropdown)

  // Dropdown Values
  String? _selectedDept;
  String? _selectedPos;
  String? _selectedRole;
  String? _selectedStatus;
  DateTime? _startDate;

  // Master Data for Dropdowns
  List<String> _departments = [];
  List<String> _positions = [];
  final List<String> _roles = ['admin', 'organizer', 'employee'];
  final List<String> _statuses = ['Active', 'Resigned', 'Suspended'];
  final List<String> _titles = ['Mr.', 'Ms.', 'Mrs.', 'Dr.'];

  @override
  void initState() {
    super.initState();
    _loadMasterData();
    _initializeFields();
  }

  void _initializeFields() {
    final e = widget.employeeData;
    _nameCtrl.text = e['name'] ?? '';
    _emailCtrl.text = e['email'] ?? '';
    _phoneCtrl.text = e['phone'] ?? '';
    
    // Extract Title if possible (Backend อาจไม่ได้ส่ง Title แยกมาใน List API)
    // สมมติว่าต้องกรอกใหม่หรือเลือกใหม่
    
    _selectedRole = e['role']?.toString().toLowerCase();
    _selectedStatus = e['status'];
    
    // Initial Value for Dept/Pos (จะถูก override ถ้าโหลด master data เสร็จแล้วมีค่าตรงกัน)
    _selectedDept = e['department'];
    // _selectedPos = e['position']; // ต้องระวังถ้า Position ไม่อยู่ใน Master List
  }

  Future<void> _loadMasterData() async {
    final depts = await _service.getDepartments();
    final positions = await _service.getPositions();
    
    if (mounted) {
      setState(() {
        _departments = depts;
        _positions = positions;
        
        // ตรวจสอบว่าค่าเดิมมีอยู่ใน List ไหม ถ้าไม่มีให้เพิ่มเข้าไป (เพื่อไม่ให้ Dropdown พัง)
        final currentPos = widget.employeeData['position'];
        if (currentPos != null && !_positions.contains(currentPos)) {
          _positions.add(currentPos);
        }
        _selectedPos = currentPos;

        final currentDept = widget.employeeData['department'];
        if (currentDept != null && !_departments.contains(currentDept)) {
           // ถ้าเป็น Other Dept ให้เพิ่ม
           _departments.add(currentDept);
        }
        _selectedDept = currentDept;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final payload = {
      "title": _titleCtrl.text.isEmpty ? "K." : _titleCtrl.text, // Default Title
      "name": _nameCtrl.text,
      "phone": _phoneCtrl.text,
      "email": _emailCtrl.text,
      "department_id": _selectedDept,
      "position": _selectedPos,
      "role": _selectedRole,
      "status": _selectedStatus,
      "start_date": _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : "2024-01-01" // Default date if missing
    };

    final success = await _service.updateEmployee(widget.employeeData['id'], payload);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context, true); // Return true to refresh list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Employee updated!"), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD), // สีพื้นหลังเทาอ่อนแบบ Reward Form
      appBar: AppBar(
        title: Text("Edit Profile", style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A80FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving 
              ? const CircularProgressIndicator(color: Colors.white) 
              : Text("SAVE CHANGES", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Section 1: Identity ---
              _buildSectionTitle("Personal Info"),
              _buildCardForm([
                _buildTextField("Full Name", _nameCtrl, required: true),
                const SizedBox(height: 16),
                _buildDropdown("Title (Optional)", _titleCtrl.text.isEmpty ? null : _titleCtrl.text, _titles, (v) => setState(()=>_titleCtrl.text = v!)),
                const SizedBox(height: 16),
                _buildTextField("Email", _emailCtrl, required: true),
                const SizedBox(height: 16),
                _buildTextField("Phone", _phoneCtrl, isNumber: true),
              ]),
              
              const SizedBox(height: 24),
              
              // --- Section 2: Work Info ---
              _buildSectionTitle("Organization Details"),
              _buildCardForm([
                _buildDropdown("Department", _selectedDept, _departments, (v) => setState(()=>_selectedDept = v)),
                const SizedBox(height: 16),
                // Position สามารถเลือกจาก Dropdown หรือพิมพ์เองก็ได้ (ใช้ Autocomplete หรือ TextField + Dropdown ก็ได้)
                // ในที่นี้ใช้ Dropdown แบบพื้นฐานไปก่อน
                 _buildDropdown("Position", _selectedPos, _positions, (v) => setState(()=>_selectedPos = v)),
                 
                 const SizedBox(height: 16),
                 Row(
                   children: [
                     Expanded(child: _buildDropdown("Role", _selectedRole, _roles, (v) => setState(()=>_selectedRole = v))),
                     const SizedBox(width: 16),
                     Expanded(child: _buildDropdown("Status", _selectedStatus, _statuses, (v) => setState(()=>_selectedStatus = v))),
                   ],
                 )
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ... (Reuse Widgets from Reward Form) ...
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[600])),
    );
  }

  Widget _buildCardForm(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {bool isNumber = false, bool required = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: required ? (v) => v!.isEmpty ? "Required" : null : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
  
  Widget _buildDropdown(String label, String? value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : null,
              isExpanded: true,
              hint: Text("Select $label"),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}