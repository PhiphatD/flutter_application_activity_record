import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/admin_service.dart';
import '../../../widgets/custom_confirm_dialog.dart';
import '../../../widgets/auto_close_success_dialog.dart';

class AdminEmployeeEditScreen extends StatefulWidget {
  final Map<String, dynamic>? employeeData; // [CHANGE] ทำให้เป็น Nullable
  const AdminEmployeeEditScreen({
    super.key,
    this.employeeData,
  }); // [CHANGE] remove required

  @override
  State<AdminEmployeeEditScreen> createState() =>
      _AdminEmployeeEditScreenState();
}

class _AdminEmployeeEditScreenState extends State<AdminEmployeeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final AdminService _service = AdminService();
  bool _isSaving = false;
  bool _isLoadingData = true; // เพิ่ม State Loading เพื่อรอ Master Data

  // [NEW] Helper Getter
  bool get isEditMode => widget.employeeData != null;

  // Controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _customTitleCtrl =
      TextEditingController(); // Controller สำหรับ Title ที่กรอกเอง
  final _customDeptCtrl = TextEditingController(); // [NEW]
  final _customPosCtrl = TextEditingController(); // [NEW]

  // Dropdown Values
  String? _selectedTitle;
  String? _selectedDept;
  String? _selectedPos;
  String? _selectedRole;
  String? _selectedStatus;

  // Change Log Snapshot
  late Map<String, dynamic> _initialData;

  // Master Data Lists
  List<String> _departments = [];
  List<String> _positions = [];
  final List<String> _roles = ['admin', 'organizer', 'employee'];
  final List<String> _statuses = ['Active', 'Resigned', 'Suspended'];

  // Standard Titles + API Titles
  List<String> _titles = ['Mr.', 'Mrs.', 'Ms.', 'Dr.'];
  bool _showCustomTitleField = false;
  bool _showCustomDeptField = false; // [NEW]
  bool _showCustomPosField = false; // [NEW]

  @override
  void initState() {
    super.initState();
    // รวม Process การโหลดข้อมูลและการ Map ค่าไว้ที่เดียวเพื่อลด Race Condition
    _initializeAndLoadData();
  }

  Future<void> _initializeAndLoadData() async {
    try {
      // 1. ดึงค่า Title (ถ้า Backend แก้แล้ว ค่านี้จะไม่เป็น Null ครับ)
      String dbTitle = isEditMode
          ? (widget.employeeData!['title'] ??
                    widget.employeeData!['EMP_TITLE_EN'] ??
                    "")
                .toString()
                .trim()
          : "";

      // [DEBUG] เช็คค่าที่ Console: ถ้าขึ้นว่างเปล่า แปลว่า Backend ยังไม่ส่งมา
      print("DEBUG: Title received from DB is '$dbTitle'");

      String currentName = isEditMode
          ? (widget.employeeData!['name'] ?? "").toString()
          : "";
      String currentEmail = isEditMode
          ? (widget.employeeData!['email'] ?? "").toString()
          : "";
      String currentPhone = isEditMode
          ? (widget.employeeData!['phone'] ?? "").toString()
          : "";
      String currentDept = isEditMode
          ? (widget.employeeData!['department'] ?? "")
          : "";
      String currentPos = isEditMode
          ? (widget.employeeData!['position'] ?? "")
          : "";
      String currentRole = isEditMode
          ? (widget.employeeData!['role'] ?? "employee")
                .toString()
                .toLowerCase()
          : "employee";
      String currentStatus = isEditMode
          ? (widget.employeeData!['status'] ?? "Active")
          : "Active";

      // 2. โหลด Master Data
      final results = await Future.wait([
        _service.getTitles(),
        _service.getDepartments(),
        _service.getPositions(),
      ]);

      final apiTitles = results[0] as List<String>;
      final apiDepts = results[1] as List<String>;
      final apiPositions = results[2] as List<String>;

      if (mounted) {
        setState(() {
          // --- A. Title Logic (ฉบับแก้ไขสมบูรณ์) ---
          Set<String> titleSet = {..._titles, ...apiTitles};

          if (dbTitle.isNotEmpty) {
            // Force Add ลง Set เลย เพื่อให้มั่นใจว่า Dropdown มีค่านี้ให้เลือกแน่นอน
            // (Set จะจัดการเรื่องค่าซ้ำให้เอง)
            titleSet.add(dbTitle);

            // เลือกค่านั้นทันที
            _selectedTitle = dbTitle;

            // เช็คว่าเป็นค่าแปลกๆ หรือไม่ (เผื่ออยากให้เด้ง Other)
            // แต่ในที่นี้เน้นให้โชว์ค่าเดิมให้ได้ก่อน
            _showCustomTitleField = false;
          } else {
            _selectedTitle = null;
            _showCustomTitleField = false;
          }

          // เพิ่ม Other ปิดท้าย
          titleSet.add('Other');
          _titles = titleSet.toList();

          // --- B. Department Logic (ปรับใหม่รองรับ Other) ---
          _departments = List.from(apiDepts); // ก๊อปปี้ List มา
          if (!_departments.contains('Other'))
            _departments.add('Other'); // เพิ่ม Other

          if (currentDept.isNotEmpty && !_departments.contains(currentDept)) {
            // ถ้าค่าเดิม ไม่มีใน List -> เลือก Other + ใส่ค่าเดิมในช่องกรอก
            _selectedDept = 'Other';
            _customDeptCtrl.text = currentDept;
            _showCustomDeptField = true;
          } else {
            // ถ้ามีใน List หรือเป็นค่าว่าง
            _selectedDept = _departments.contains(currentDept)
                ? currentDept
                : null;
            _showCustomDeptField = false;
          }

          // --- C. Position Logic (ปรับใหม่รองรับ Other) ---
          _positions = List.from(apiPositions);
          if (!_positions.contains('Other')) _positions.add('Other');

          if (currentPos.isNotEmpty && !_positions.contains(currentPos)) {
            _selectedPos = 'Other';
            _customPosCtrl.text = currentPos;
            _showCustomPosField = true;
          } else {
            _selectedPos = _positions.contains(currentPos) ? currentPos : null;
            _showCustomPosField = false;
          }

          // --- C. Other Fields ---
          _nameCtrl.text = currentName;
          _emailCtrl.text = currentEmail;
          _phoneCtrl.text = currentPhone;
          _selectedRole = _roles.contains(currentRole)
              ? currentRole
              : 'employee';
          _selectedStatus = currentStatus;

          // --- D. Save Snapshot ---
          _initialData = {
            'title': _selectedTitle,
            'name': currentName,
            'email': currentEmail,
            'phone': currentPhone,
            'department': currentDept,
            'position': currentPos,
            'role': currentRole,
            'status': currentStatus,
          };

          _isLoadingData = false;
        });
      }
    } catch (e) {
      print("Error initializing: $e");
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  // สร้างข้อความสรุปการเปลี่ยนแปลง
  String _generateChangeSummary() {
    List<String> changes = [];

    // Helper function to compare
    void check(String label, String initialVal, String currentVal) {
      if (initialVal != currentVal) {
        changes.add("• $label: $initialVal ➝ $currentVal");
      }
    }

    // Logic หาค่า Title จริงๆ ที่จะส่ง (Dropdown หรือ Custom Text)
    String currentRealTitle = _selectedTitle ?? "";
    if (_selectedTitle == 'Other') {
      currentRealTitle = _customTitleCtrl.text.trim();
    }

    check("Title", _initialData['title'], currentRealTitle);
    check("Name", _initialData['name'], _nameCtrl.text);
    check("Email", _initialData['email'], _emailCtrl.text);
    check("Phone", _initialData['phone'], _phoneCtrl.text);
    check("Dept", _initialData['department'], _selectedDept ?? "");
    check("Position", _initialData['position'], _selectedPos ?? "");
    check("Role", _initialData['role'], _selectedRole ?? "");
    check("Status", _initialData['status'], _selectedStatus ?? "");

    if (changes.isEmpty) return "No changes detected.";
    return changes.join("\n");
  }

  void _confirmAndSubmit() {
    if (!_formKey.currentState!.validate()) return;

    // Validation เพิ่มเติมสำหรับ Custom Title
    if (_selectedTitle == 'Other' && _customTitleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please specify the title.")),
      );
      return;
    }

    String summary = _generateChangeSummary();

    if (summary == "No changes detected.") {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No changes to save.")));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => CustomConfirmDialog.success(
        title: "Confirm Updates",
        subtitle: "Please review the changes:\n\n$summary",
        confirmText: "Confirm & Save",
        onConfirm: () {
          Navigator.pop(ctx);
          _submit();
        },
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);

    // [CORE LOGIC] Determine Final Title
    String finalTitle = _selectedTitle ?? "";
    if (_selectedTitle == 'Other') {
      finalTitle = _customTitleCtrl.text.trim();
      // Fallback to K. if empty (though validation should catch this)
      if (finalTitle.isEmpty) finalTitle = "K.";
    }

    // [NEW] Department Logic
    String finalDept = _selectedDept ?? "";
    if (_selectedDept == 'Other') finalDept = _customDeptCtrl.text.trim();

    // [NEW] Position Logic
    String finalPos = _selectedPos ?? "";
    if (_selectedPos == 'Other') finalPos = _customPosCtrl.text.trim();

    final payload = {
      "title": finalTitle,
      "name": _nameCtrl.text.trim(),
      "phone": _phoneCtrl.text.trim(),
      "email": _emailCtrl.text.trim(),
      "department_id": finalDept, // Backend จะไปจัดการ map/create ให้เอง
      "position": finalPos,
      "role": _selectedRole,
      "status": _selectedStatus,
      // Start date ต้องส่งไปด้วยถ้า API บังคับ แต่ในที่นี้ EmployeeUpdateRequest ต้องการ
      // เราอาจจะต้องดึง start_date เดิมมาส่ง หรือให้ API handle การ update partial
      // สมมติว่าส่งค่าเดิมกลับไป
      "start_date": isEditMode
          ? (widget.employeeData!['EMP_STARTDATE'] ??
                DateTime.now().toString().substring(0, 10))
          : DateTime.now().toString().substring(0, 10),
    };

    // Add password for create mode
    if (!isEditMode) {
      payload['password'] = "123456";
    }

    final prefs = await SharedPreferences.getInstance();
    final adminId = prefs.getString('empId') ?? '';

    bool success;
    if (isEditMode) {
      success = await _service.updateEmployee(
        widget.employeeData!['id'],
        payload,
      );
    } else {
      success = await _service.createEmployee(adminId, payload);
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        await showDialog(
          context: context,
          builder: (context) => AutoCloseSuccessDialog(
            title: isEditMode ? "Profile Updated" : "Employee Created",
            subtitle: isEditMode
                ? "Changes saved successfully."
                : "New account created (Pwd: 123456)",
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to update. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FD),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(
          isEditMode ? "Edit Employee" : "New Employee",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _confirmAndSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A80FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    isEditMode ? "SAVE CHANGES" : "CREATE ACCOUNT",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
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
              _buildSectionTitle("Personal Info"),
              _buildCardForm([
                // Title Dropdown with Logic
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildModernDropdown(
                        "Title",
                        _selectedTitle,
                        _titles,
                        (val) {
                          setState(() {
                            _selectedTitle = val;
                            _showCustomTitleField = (val == 'Other');
                            if (!_showCustomTitleField) {
                              _customTitleCtrl.clear();
                            }
                          });
                        },
                      ),
                    ),
                    // Show Text Field if Other is selected
                    if (_showCustomTitleField) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: _buildTextField(
                          "Specify (e.g. Gen.)",
                          _customTitleCtrl,
                          required: true,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),
                _buildTextField("Full Name", _nameCtrl, required: true),

                const SizedBox(height: 16),
                _buildTextField("Email", _emailCtrl, required: true),

                const SizedBox(height: 16),
                _buildTextField("Phone", _phoneCtrl, isNumber: true),
              ]),

              const SizedBox(height: 24),

              _buildSectionTitle("Organization Details"),
              _buildCardForm([
                // --- 1. Department Section ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildModernDropdown(
                        "Department",
                        _selectedDept,
                        _departments,
                        (v) {
                          setState(() {
                            _selectedDept = v;
                            _showCustomDeptField = (v == 'Other');
                            if (!_showCustomDeptField) _customDeptCtrl.clear();
                          });
                        },
                      ),
                    ),
                    // Show Text Field if Other
                    if (_showCustomDeptField) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: _buildTextField(
                          "Specify Department",
                          _customDeptCtrl,
                          required: true,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // --- 2. Position Section ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildModernDropdown(
                        "Position",
                        _selectedPos,
                        _positions,
                        (v) {
                          setState(() {
                            _selectedPos = v;
                            _showCustomPosField = (v == 'Other');
                            if (!_showCustomPosField) _customPosCtrl.clear();
                          });
                        },
                      ),
                    ),
                    // Show Text Field if Other
                    if (_showCustomPosField) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: _buildTextField(
                          "Specify Position",
                          _customPosCtrl,
                          required: true,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // --- 3. Role & Status (เหมือนเดิม) ---
                Row(
                  children: [
                    Expanded(
                      child: _buildModernDropdown(
                        "Role",
                        _selectedRole,
                        _roles,
                        (v) => setState(() => _selectedRole = v),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildModernDropdown(
                        "Status",
                        _selectedStatus,
                        _statuses,
                        (v) => setState(() => _selectedStatus = v),
                      ),
                    ),
                  ],
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ... (Reused Widgets: _buildSectionTitle, _buildCardForm, _buildTextField, _buildModernDropdown from previous code)
  // Paste the UI Helper widgets here (same as your previous file content)

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildCardForm(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl, {
    bool isNumber = false,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          validator: required ? (v) => v!.isEmpty ? "Required" : null : null,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4A80FF)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernDropdown(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : null,
              isExpanded: true,
              hint: Text(
                "Select $label",
                style: GoogleFonts.poppins(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.grey,
              ),
              style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
              items: items
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, style: GoogleFonts.poppins(fontSize: 14)),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
