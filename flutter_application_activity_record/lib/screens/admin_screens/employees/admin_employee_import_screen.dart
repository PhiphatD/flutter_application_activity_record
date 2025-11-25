import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dotted_border/dotted_border.dart';
import '../../../services/admin_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AdminEmployeeImportScreen extends StatefulWidget {
  const AdminEmployeeImportScreen({super.key});

  @override
  State<AdminEmployeeImportScreen> createState() =>
      _AdminEmployeeImportScreenState();
}

class _AdminEmployeeImportScreenState extends State<AdminEmployeeImportScreen> {
  File? _selectedFile;
  bool _isUploading = false;
  final AdminService _service = AdminService();

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      // 1. เนื้อหา CSV (Header + ตัวอย่าง 1 แถว)
      // ต้องตรงกับที่ Backend (main.py) รอรับ
      const String csvContent =
          "Title,Name,Position,Department,Email,Phone,Password,Role,StartDate\n"
          "Mr.,John Doe,Software Engineer,IT,john.d@example.com,0812345678,123456,Employee,2025-01-01\n"
          "Ms.,Jane Smith,HR Manager,Human Resources,jane.s@example.com,0898765432,123456,Organizer,2025-02-15";

      // 2. หา Path ชั่วคราวในเครื่อง
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/employee_import_template.csv';
      final file = File(path);

      // 3. เขียนไฟล์
      await file.writeAsString(csvContent);

      // 4. แชร์ไฟล์ (เพื่อให้ผู้ใช้เลือก Save to Files หรือส่งเข้าคอม)
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Employee Import Template',
        subject: 'employee_template.csv',
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error creating template: $e")));
    }
  }

  void _clearFile() {
    setState(() => _selectedFile = null);
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) return;

    setState(() => _isUploading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final adminId = prefs.getString('empId') ?? '';

      final result = await _service.importEmployees(adminId, _selectedFile!);

      if (mounted) {
        _showResultDialog(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showResultDialog(Map<String, dynamic> result) {
    final successCount = result['success_count'] ?? 0;
    final errors = List<String>.from(result['errors'] ?? []);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              errors.isEmpty ? Icons.check_circle : Icons.warning_amber_rounded,
              color: errors.isEmpty ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 10),
            Text(
              "Import Result",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Successfully imported: $successCount users",
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.green[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (errors.isNotEmpty) ...[
              Text(
                "Issues found (${errors.length}):",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 150,
                width: double.maxFinite,
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: errors.length,
                  itemBuilder: (c, i) => Text(
                    "• ${errors[i]}",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.red[900],
                    ),
                  ),
                ),
              ),
            ] else
              Text(
                "All data processed correctly.",
                style: GoogleFonts.inter(color: Colors.grey[600]),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              if (errors.isEmpty) {
                Navigator.pop(context, true); // Close screen if success
              } else {
                _clearFile(); // Clear file to try again
              }
            },
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Bulk Import",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Instructions
            _buildInstructionCard(),
            const SizedBox(height: 32),

            // 2. Upload Area
            Text(
              "Upload CSV File",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildUploadZone(),

            const SizedBox(height: 40),

            // 3. Action Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: (_selectedFile != null && !_isUploading)
                    ? _uploadFile
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A80FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isUploading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            "Processing...",
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      )
                    : Text(
                        "Start Import",
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

  Widget _buildInstructionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF4A80FF)),
                  const SizedBox(width: 10),
                  Text(
                    "Instructions",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStep(1, "Download the template file below."),
          _buildStep(2, "Fill in employee details (Email must be unique)."),
          _buildStep(3, "Upload the completed CSV file."),

          const SizedBox(height: 20),

          // [NEW] ปุ่ม Download Template
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _downloadTemplate,
              icon: const Icon(Icons.download_rounded, size: 20),
              label: Text(
                "Download CSV Template",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4A80FF),
                side: const BorderSide(color: Color(0xFF4A80FF)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$num. ",
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(color: Colors.grey[600], height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadZone() {
    if (_selectedFile != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.description, color: Colors.green),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedFile!.path.split('/').last,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[900],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Ready to upload",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _isUploading ? null : _clearFile,
              icon: const Icon(Icons.close, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _pickFile,
      child: DottedBorder(
        color: const Color(0xFF4A80FF).withOpacity(0.5),
        strokeWidth: 2,
        dashPattern: const [8, 4],
        borderType: BorderType.RRect,
        radius: const Radius.circular(16),
        child: Container(
          height: 180,
          width: double.infinity,
          color: const Color(0xFFF5F7FA).withOpacity(0.3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6EFFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  size: 32,
                  color: Color(0xFF4A80FF),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Tap to browse file",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Support CSV files only",
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
