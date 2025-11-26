import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/admin_service.dart';
import '../../../widgets/custom_confirm_dialog.dart';
import '../../../widgets/auto_close_success_dialog.dart';

class AdminRewardFormScreen extends StatefulWidget {
  final Map<String, dynamic>? reward;
  const AdminRewardFormScreen({super.key, this.reward});

  @override
  State<AdminRewardFormScreen> createState() => _AdminRewardFormScreenState();
}

class _AdminRewardFormScreenState extends State<AdminRewardFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _instructionCtrl = TextEditingController();
  final _urlInputCtrl = TextEditingController();

  // Data State
  List<String> _imageUrls = [];
  List<File> _newImages = [];

  // Dropdown Data
  String _selectedType = "Physical"; // Default Value
  final List<String> _types = ["Physical", "Digital", "Privilege"];

  bool _isSaving = false;
  final AdminService _service = AdminService();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.reward != null) {
      _loadExistingData();
    }
  }

  void _loadExistingData() {
    final r = widget.reward!;
    _nameCtrl.text = r['name'];
    _pointsCtrl.text = r['pointCost'].toString();
    _stockCtrl.text = r['stock'].toString();
    _descCtrl.text = r['description'] ?? '';
    _selectedType = r['prizeType'] ?? "Physical";
    _instructionCtrl.text = r['pickupInstruction'] ?? "";

    if (r['images'] != null) {
      _imageUrls = List<String>.from(r['images']);
    } else if (r['image'] != null && r['image'].toString().isNotEmpty) {
      _imageUrls.add(r['image']);
    }
  }

  // --- Image Logic ---
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

  Future<void> _pickImages() async {
    if (_totalImages >= 10) {
      _showError("Maximum 10 images allowed.");
      return;
    }
    final List<XFile> picked = await _picker.pickMultiImage(
      limit: 10 - _totalImages,
    );
    if (picked.isNotEmpty)
      setState(() {
        _newImages.addAll(picked.map((e) => File(e.path)));
      });
  }

  int get _totalImages => _imageUrls.length + _newImages.length;

  // --- Submit Logic ---
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_totalImages == 0) {
      _showError("Please add at least 1 image.");
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Upload Images
      List<String> finalImages = List.from(_imageUrls);
      for (var file in _newImages) {
        String? uploadedUrl = await _service.uploadImage(file);
        if (uploadedUrl != null) finalImages.add(uploadedUrl);
      }

      final prefs = await SharedPreferences.getInstance();
      final adminId = prefs.getString('empId') ?? '';

      final data = {
        "name": _nameCtrl.text.trim(),
        "point_cost": int.parse(_pointsCtrl.text),
        "stock": int.parse(_stockCtrl.text),
        "description": _descCtrl.text.trim(),
        "images": finalImages,
        "prize_type": _selectedType,
        "pickup_instruction": _instructionCtrl.text.trim(),
      };

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
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const AutoCloseSuccessDialog(
              title: "Saved Successfully",
              subtitle: "Reward data has been updated.",
              icon: Icons.check_circle,
              color: Colors.green,
            ),
          );
          Navigator.pop(context, true);
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
      builder: (ctx) => CustomConfirmDialog.danger(
        title: "Delete Reward?",
        subtitle: "This item will be hidden. Cannot undo.",
        confirmText: "Yes, Delete",
        onConfirm: () async {
          Navigator.pop(ctx);
          setState(() => _isSaving = true);
          final prefs = await SharedPreferences.getInstance();
          final adminId = prefs.getString('empId') ?? '';
          final success = await _service.deleteReward(
            adminId,
            widget.reward!['id'],
          );

          if (mounted) {
            if (success) {
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const AutoCloseSuccessDialog(
                  title: "Deleted",
                  subtitle: "Reward removed.",
                  icon: Icons.delete,
                  color: Colors.red,
                ),
              );
              Navigator.pop(context, true);
            } else {
              setState(() => _isSaving = false);
              _showError("Failed to delete");
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.reward != null;
    // [CORE FIX] ใช้ MediaQuery เพื่อหาพื้นที่ Safe Area ด้านล่าง
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
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
      // [CORE FIX] ปรับ Bottom Bar ให้รองรับ Safe Area
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPadding),
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
              elevation: 0,
            ),
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    "SAVE REWARD",
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
              _buildSectionTitle("Images (${_totalImages}/10)"),
              const SizedBox(height: 10),
              _buildImageManager(),

              const SizedBox(height: 24),
              _buildSectionTitle("Basic Info"),
              _buildCardForm([
                _buildTextField("Reward Name", _nameCtrl, required: true),
                const SizedBox(height: 16),

                // Row for Points & Stock
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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

                // [NEW UI] Modern Dropdown for Type
                _buildModernDropdown("Type", _selectedType, _types, (val) {
                  if (val != null) setState(() => _selectedType = val);
                }),
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

              // เพิ่มพื้นที่ว่างด้านล่างกันตกขอบ
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI Helpers ---

  Widget _buildImageManager() {
    return Column(
      children: [
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
                      onTap: () => setState(() {
                        if (isUrl)
                          _imageUrls.removeAt(index);
                        else
                          _newImages.removeAt(index - _imageUrls.length);
                      }),
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
                  if (!isUrl)
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
              border: Border.all(color: Colors.grey.shade300),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
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

  // [NEW] Modern TextField Style (Reuse from Employee Edit)
  Widget _buildTextField(
    String label,
    TextEditingController ctrl, {
    bool isNumber = false,
    int maxLines = 1,
    bool required = false,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          maxLines: maxLines,
          validator: required
              ? (v) => v == null || v.isEmpty ? "Required" : null
              : null,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
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

  // [NEW] Modern Dropdown Widget
  Widget _buildModernDropdown(
    String label,
    String value,
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
