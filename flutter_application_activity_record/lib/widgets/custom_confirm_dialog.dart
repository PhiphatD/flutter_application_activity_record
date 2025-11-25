// lib/widgets/custom_confirm_dialog.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomConfirmDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;
  final Color confirmColor;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  const CustomConfirmDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onConfirm,
    this.confirmText = "Confirm",
    this.cancelText = "Cancel",
    this.confirmColor = const Color(0xFF4A80FF), // Default Blue
    this.icon = Icons.info_outline,
    this.iconColor = const Color(0xFF4A80FF),
    this.iconBgColor = const Color(0xFFE6EFFF), // Light Blue
  });

  // Factory constructor สำหรับการลบ/ยกเลิก (สีแดง)
  factory CustomConfirmDialog.danger({
    required String title,
    required String subtitle,
    required VoidCallback onConfirm,
    String confirmText = "Yes, Delete",
  }) {
    return CustomConfirmDialog(
      title: title,
      subtitle: subtitle,
      onConfirm: onConfirm,
      confirmText: confirmText,
      confirmColor: Colors.red,
      icon: Icons.delete_outline,
      iconColor: Colors.red,
      iconBgColor: Colors.red.shade50,
    );
  }

  // Factory constructor สำหรับการยืนยันทั่วไป (สีเขียว/ฟ้า)
  factory CustomConfirmDialog.success({
    required String title,
    required String subtitle,
    required VoidCallback onConfirm,
    String confirmText = "Confirm",
  }) {
    return CustomConfirmDialog(
      title: title,
      subtitle: subtitle,
      onConfirm: onConfirm,
      confirmText: confirmText,
      confirmColor: const Color(0xFF4A80FF),
      icon: Icons.check_circle_outline,
      iconColor: const Color(0xFF4A80FF),
      iconBgColor: const Color(0xFFE6EFFF),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 32),
            ),
            const SizedBox(height: 20),

            // 2. Texts
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.kanit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.kanit(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // 3. Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      foregroundColor: Colors.grey[700],
                    ),
                    child: Text(
                      cancelText,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: confirmColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      confirmText,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
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
  }
}