import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/admin_service.dart';

class AdminRewardFormScreen extends StatefulWidget {
  final Map<String, dynamic>? reward;
  const AdminRewardFormScreen({super.key, this.reward});

  @override
  State<AdminRewardFormScreen> createState() => _AdminRewardFormScreenState();
}

class _AdminRewardFormScreenState extends State<AdminRewardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _instructionCtrl = TextEditingController();

  // Image State
  final _urlInputCtrl = TextEditingController();
  List<String> _imageUrls = []; // รูปที่เป็น URL อยู่แล้ว (จาก DB หรือกรอกเอง)
  List<File> _newImages = []; // รูปใหม่ที่เลือกจากเครื่อง (รออัปโหลด)

  String _selectedType = "Physical";
  final List<String> _types = ["Physical", "Digital", "Privilege"];

  bool _isSaving = false;
  final AdminService _service = AdminService();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.reward != null) {
      final r = widget.reward!;
      _nameCtrl.text = r['name'];
      _pointsCtrl.text = r['pointCost'].toString();
      _stockCtrl.text = r['stock'].toString();
      _descCtrl.text = r['description'] ?? '';
      _selectedType = r['prizeType'] ?? "Physical";
      _instructionCtrl.text = r['pickupInstruction'] ?? "";

      // Load existing images
      if (r['images'] != null) {
        _imageUrls = List<String>.from(r['images']);
      } else if (r['image'] != null && r['image'].toString().isNotEmpty) {
        // Legacy support
        _imageUrls.add(r['image']);
      }
    }
  }

  // ฟังก์ชันเพิ่ม URL
  void _addUrlImage() {
    if (_urlInputCtrl.text.isNotEmpty) {
      if (_totalImages >= 10) {
        _showError("Maximum 10 images allowed.");
        return;
      }
      setState(() {
        _imageUrls.add(_urlInputCtrl.text.trim());
        _urlInputCtrl.clear();
      });
    }
  }

  // ฟังก์ชันเลือกรูปจากเครื่อง
  Future<void> _pickImages() async {
    if (_totalImages >= 10) {
      _showError("Maximum 10 images allowed.");
      return;
    }

    final List<XFile> picked = await _picker.pickMultiImage(
      limit: 10 - _totalImages, // จำกัดจำนวนที่เลือกได้
    );

    if (picked.isNotEmpty) {
      setState(() {
        _newImages.addAll(picked.map((e) => File(e.path)));
      });
    }
  }

  int get _totalImages => _imageUrls.length + _newImages.length;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_totalImages == 0) {
      _showError("Please add at least 1 image.");
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Upload New Images First
      List<String> finalImages = List.from(_imageUrls);

      for (var file in _newImages) {
        String? uploadedUrl = await _service.uploadImage(file);
        if (uploadedUrl != null) {
          finalImages.add(uploadedUrl);
        }
      }

      // 2. Prepare Payload
      final prefs = await SharedPreferences.getInstance();
      final adminId = prefs.getString('empId') ?? '';

      final data = {
        "name": _nameCtrl.text,
        "point_cost": int.parse(_pointsCtrl.text),
        "stock": int.parse(_stockCtrl.text),
        "description": _descCtrl.text,
        "images": finalImages, // ส่งเป็น List
        "prize_type": _selectedType,
        "pickup_instruction": _instructionCtrl.text,
      };

      // 3. Call API
      bool success;
      if (widget.reward == null) {
        success = await _service.createReward(adminId, data);
      } else {
        success = await _service.updateReward(
          adminId,
          widget.reward!['id'],
          data,
        );
      }

      if (mounted) {
        if (success) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Saved successfully"),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          _showError("Failed to save reward.");
        }
      }
    } catch (e) {
      _showError("Error: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Reward?"),
        content: const Text("This item will be hidden from employees."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // ปิด Dialog
              setState(() => _isSaving = true);

              final prefs = await SharedPreferences.getInstance();
              final adminId = prefs.getString('empId') ?? '';

              // เรียก Service ลบ
              final success = await _service.deleteReward(
                adminId,
                widget.reward!['id'],
              );

              if (mounted) {
                if (success) {
                  Navigator.pop(context, true); // กลับหน้าหลักและรีเฟรช
                } else {
                  setState(() => _isSaving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Failed to delete")),
                  );
                }
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.reward != null;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          isEdit ? "Edit Reward" : "New Reward",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
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
            onPressed: _isSaving ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A80FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    "SAVE REWARD",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
              _buildSectionTitle("Images (${_totalImages}/10)"),
              const SizedBox(height: 10),
              _buildImageManager(),

              const SizedBox(height: 24),
              _buildSectionTitle("Basic Info"),
              _buildCardForm([
                _buildTextField("Reward Name", _nameCtrl, required: true),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        "Points",
                        _pointsCtrl,
                        isNumber: true,
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        "Stock",
                        _stockCtrl,
                        isNumber: true,
                        required: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  items: _types
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedType = v!),
                  decoration: _inputDecoration("Type"),
                ),
              ]),

              const SizedBox(height: 24),
              _buildSectionTitle("Details"),
              _buildCardForm([
                _buildTextField("Description", _descCtrl, maxLines: 4),
                const SizedBox(height: 16),
                _buildTextField(
                  "Instruction (Pickup/Usage)",
                  _instructionCtrl,
                  hint: "e.g. Contact HR at 2nd Floor",
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // [NEW UI] ส่วนจัดการรูปภาพ (แสดงรูป + ปุ่มเพิ่ม)
  Widget _buildImageManager() {
    return Column(
      children: [
        // Input URL
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                "Add Image URL",
                _urlInputCtrl,
                hint: "https://...",
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _addUrlImage,
              icon: const Icon(Icons.link),
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.black,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _pickImages,
              icon: const Icon(Icons.upload_file),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF4A80FF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Image Grid
        if (_totalImages > 0)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: _totalImages,
            itemBuilder: (context, index) {
              // Logic: แสดง URL ก่อน แล้วตามด้วย File
              final bool isUrl = index < _imageUrls.length;
              final imageProvider = isUrl
                  ? NetworkImage(_imageUrls[index])
                  : FileImage(_newImages[index - _imageUrls.length])
                        as ImageProvider;

              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isUrl) {
                            _imageUrls.removeAt(index);
                          } else {
                            _newImages.removeAt(index - _imageUrls.length);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (!isUrl) // Badge for New Upload
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "NEW",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          )
        else
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey.shade300,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.image_outlined, color: Colors.grey, size: 40),
                const SizedBox(height: 8),
                Text(
                  "No images added",
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
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

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
      labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl, {
    bool isNumber = false,
    int maxLines = 1,
    bool required = false,
    String? hint,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      validator: required
          ? (v) => v == null || v.isEmpty ? "Required" : null
          : null,
      decoration: _inputDecoration(label, hint: hint),
    );
  }
}
