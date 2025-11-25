import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AutoCloseSuccessDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Duration duration;

  const AutoCloseSuccessDialog({
    super.key,
    required this.title,
    this.subtitle = "",
    this.icon = Icons.check_circle,
    this.color = Colors.green,
    this.duration = const Duration(seconds: 2), // แนะนำ 2 วินาที กำลังดี
  });

  @override
  State<AutoCloseSuccessDialog> createState() => _AutoCloseSuccessDialogState();
}

class _AutoCloseSuccessDialogState extends State<AutoCloseSuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    // เริ่มนับถอยหลัง
    _controller.reverse(from: 1.0);

    // เมื่อนับจบ ให้ปิด Dialog
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 32, 0, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Icon with Circle Background
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, size: 48, color: widget.color),
            ),
            const SizedBox(height: 24),

            // 2. Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                widget.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),

            if (widget.subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.kanit(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // 3. Progress Bar (Time Line)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    value: _controller.value, // ค่าจะลดลงเรื่อยๆ
                    backgroundColor: Colors.grey[100],
                    color: widget.color, // สีเส้นตามประเภท (เขียว/ส้ม)
                    minHeight: 6,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
