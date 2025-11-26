import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/admin_service.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import '../../../widgets/custom_confirm_dialog.dart'; //
import '../../../widgets/auto_close_success_dialog.dart'; //

class AdminPointPolicyScreen extends StatefulWidget {
  const AdminPointPolicyScreen({super.key});

  @override
  State<AdminPointPolicyScreen> createState() => _AdminPointPolicyScreenState();
}

class _AdminPointPolicyScreenState extends State<AdminPointPolicyScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for Edit Form
  final _policyNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  final AdminService _service = AdminService();
  String _adminId = '';

  // [NEW] เก็บข้อมูลปัจจุบันแยกออกมาเพื่อแสดงผล
  Map<String, dynamic>? _currentPolicy;

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    _adminId = prefs.getString('empId') ?? '';

    if (_adminId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final policy = await _service.getPointPolicy(_adminId);

      if (mounted) {
        setState(() {
          _currentPolicy = policy; // เก็บข้อมูลดิบไว้แสดงผล

          // Pre-fill form ด้วยข้อมูลปัจจุบัน (เพื่อให้แก้ต่อได้ง่าย)
          _policyNameController.text = policy['policy_name'] ?? '';
          // กันไม่ให้เอาคำว่า Connection Error มาใส่ในช่อง
          if (policy['description'] != "Connection Error") {
            _descriptionController.text = policy['description'] ?? '';
          }
          _startDateController.text = policy['start_date'] ?? '';
          _endDateController.text = policy['end_date'] ?? '';

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  // [NEW] ฟังก์ชันใหม่: ตรวจสอบ Form และแสดง Dialog ยืนยันก่อน
  void _confirmSave() {
    // 1. Validate ก่อน ถ้าไม่ผ่านไม่ต้องโชว์ Dialog
    if (!_formKey.currentState!.validate()) return;

    // 2. แสดง Dialog ยืนยัน (ใช้ CustomConfirmDialog.success ธีมสีฟ้า)
    showDialog(
      context: context,
      builder: (ctx) => CustomConfirmDialog.success(
        title: "Confirm Update",
        subtitle:
            "Are you sure you want to update the point policy configuration?",
        confirmText: "Yes, Update",
        onConfirm: () {
          Navigator.pop(ctx); // ปิด Dialog ยืนยัน
          _executeSave(); // เรียกฟังก์ชันบันทึกจริง
        },
      ),
    );
  }

  // [RENAMED] เปลี่ยนชื่อจาก _savePolicy เป็น _executeSave (Logic เดิม)
  Future<void> _executeSave() async {
    // ตัด validate ออก เพราะทำใน _confirmSave แล้ว
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final payload = {
        'policy_name': _policyNameController.text,
        'start_date': _startDateController.text,
        'end_date': _endDateController.text,
        'description': _descriptionController.text,
      };

      await _service.updatePointPolicy(_adminId, payload);
      await _loadPolicy();

      if (mounted) {
        // Success Dialog (Auto Close) เหมือนเดิม
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AutoCloseSuccessDialog(
            title: "Policy Updated",
            subtitle: "Configuration saved successfully.",
            icon: Icons.check_circle,
            color: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // [NEW] ฟังก์ชันสั่งตัดคะแนนทันที
  void _confirmRunBatch() {
    showDialog(
      context: context,
      builder: (ctx) => CustomConfirmDialog.danger(
        title: "Run Expiry Batch?",
        subtitle:
            "System will expire points based on End Date: ${_currentPolicy?['end_date'] ?? 'Unknown'}\nThis action cannot be undone.",
        confirmText: "Run Batch",
        onConfirm: () async {
          Navigator.pop(ctx); // ปิด Dialog ยืนยัน

          setState(() => _isLoading = true); // Loading เดิม

          try {
            final result = await _service.triggerExpiryBatch(
              _adminId,
            ); // Logic เดิม

            if (mounted) {
              // [UPDATED] แสดงผลลัพธ์ด้วย AutoCloseSuccessDialog (สีส้ม/แดง ให้เข้ากับธีมลบ)
              // เพิ่มเวลาเป็น 4 วินาที เพื่อให้อ่านยอดตัวเลขทัน
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => AutoCloseSuccessDialog(
                  title: "Batch Complete",
                  subtitle:
                      "Processed: ${result['processed_users']} users\n"
                      "Removed: ${result['total_points_removed']} points",
                  icon: Icons.delete_sweep,
                  color: Colors.orange,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Error: $e"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          "Point Policy",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      // [FIXED] 1. ห่อด้วย SafeArea เพื่อกันไม่ให้เนื้อหาล้นไปทับ Status Bar หรือ Home Indicator
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                // [FIXED] 2. เพิ่ม Padding ด้านล่าง (bottom: 40) เพื่อให้ปุ่ม Danger Zone ลอยขึ้นมาเหนือขอบจอ
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // [SECTION 1] Current Status Card
                    _buildCurrentStatusCard(),

                    const SizedBox(height: 24),
                    Text(
                      "Update Configuration",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // [SECTION 2] Edit Form
                    _buildEditForm(),

                    const SizedBox(height: 30),

                    // [SECTION 3] Danger Zone
                    _buildDangerZone(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCurrentStatusCard() {
    final startDate = _currentPolicy?['start_date'] ?? '-';
    final endDate = _currentPolicy?['end_date'] ?? '-';
    final name = _currentPolicy?['policy_name'] ?? 'Not Set';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A80FF), Color(0xFF2E5BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A80FF).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                "ACTIVE POLICY",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.8),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: GoogleFonts.kanit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Start Date",
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      startDate,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: Colors.white24),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Expiry Date",
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      endDate,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              controller: _policyNameController,
              label: 'Policy Name',
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDatePickerField(
                    context,
                    controller: _startDateController,
                    label: 'Start Date',
                    icon: Icons.date_range,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDatePickerField(
                    context,
                    controller: _endDateController,
                    label: 'End Date (Expiry)',
                    icon: Icons.event_busy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _descriptionController,
              label: 'Description (Optional)',
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _confirmSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A80FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Update Policy',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                "Manual Trigger",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Force the system to check and expire points based on the 'End Date' configured above immediately.",
            style: GoogleFonts.inter(fontSize: 13, color: Colors.red.shade700),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: OutlinedButton.icon(
              onPressed: _confirmRunBatch,
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: const Text("Run Expiry Batch"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: true,
          validator: (v) => v!.isEmpty ? 'Required' : null,
          onTap: () => _openDatePicker(context, controller),
          decoration: InputDecoration(
            suffixIcon: Icon(icon, color: Colors.grey[400], size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  void _openDatePicker(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final initialDate = controller.text.isNotEmpty
        ? DateTime.parse(controller.text)
        : DateTime.now();

    List<DateTime?> initialValue = [initialDate];

    final values = await showModalBottomSheet<List<DateTime?>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: CalendarDatePicker2(
                config: CalendarDatePicker2Config(
                  calendarType: CalendarDatePicker2Type.single,
                  selectedDayHighlightColor: const Color(0xFF4A80FF),
                ),
                value: initialValue,
                onValueChanged: (dates) => initialValue = dates,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, initialValue),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A80FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Confirm",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (values != null && values.isNotEmpty && values[0] != null) {
      final d = values[0]!;
      controller.text = DateFormat('yyyy-MM-dd').format(d);
    }
  }
}
