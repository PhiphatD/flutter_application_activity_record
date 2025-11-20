import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class EnterpriseScannerScreen extends StatefulWidget {
  const EnterpriseScannerScreen({super.key});

  @override
  State<EnterpriseScannerScreen> createState() =>
      _EnterpriseScannerScreenState();
}

class _EnterpriseScannerScreenState extends State<EnterpriseScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isFlashOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ใช้ Stack เพื่อซ้อน Overlay บนกล้อง
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Layer
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  // เจอ QR Code แล้ว ส่งค่ากลับทันที
                  _controller.stop();
                  Navigator.pop(context, barcode.rawValue);
                  break;
                }
              }
            },
          ),

          // 2. Overlay Layer (พื้นที่มืด + กรอบโฟกัส)
          CustomPaint(
            painter: ScannerOverlayPainter(
              borderColor: Colors.white,
              borderRadius: 20,
              borderLength: 40,
              borderWidth: 8,
              cutOutSize: 280,
            ),
            child: Container(),
          ),

          // 3. UI Controls Layer (ปุ่มต่างๆ)
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        "Scan QR Code",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () {
                          _controller.toggleTorch();
                          setState(() => _isFlashOn = !_isFlashOn);
                        },
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Center Text Hint
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    "Align QR code within the frame",
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),

                const SizedBox(height: 40), // เว้นระยะจากกรอบ
                // Bottom Controls (เหมือนรูปที่ 1 - ปุ่ม My QR)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  color: Colors.black.withOpacity(0.5),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () {
                          // TODO: เปิดหน้า QR ของตัวเอง (ถ้าเป็น Employee)
                          // หรือเปิดหน้า QR กิจกรรม (ถ้าเป็น Organizer)
                          Navigator.pop(context, "SHOW_MY_QR");
                        },
                        child: Column(
                          children: [
                            const Icon(
                              Icons.qr_code_2,
                              color: Colors.white,
                              size: 32,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Activity Check-in QR Code",
                              style: GoogleFonts.kanit(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Helper: วาดกรอบสี่เหลี่ยมเจาะรู (เหมือนรูปที่ 1 เป๊ะๆ) ---
class ScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;
  final double cutOutSize;

  ScannerOverlayPainter({
    required this.borderColor,
    required this.borderRadius,
    required this.borderLength,
    required this.borderWidth,
    required this.cutOutSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // 1. สร้าง Path ของพื้นหลัง (เต็มจอ)
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, width, height));

    // 2. สร้าง Path ของรูเจาะตรงกลาง
    final cutOutRect = Rect.fromCenter(
      center: Offset(width / 2, height / 2),
      width: cutOutSize,
      height: cutOutSize,
    );

    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
      );

    // [FIX] 3. ใช้ PathOperation.difference เพื่อตัดรูเจาะออกจากพื้นหลัง
    // วิธีนี้จะวาดสีดำทับเฉพาะส่วนรอบนอก ส่วนตรงกลางจะโปร่งใสแน่นอน 100%
    final maskPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    canvas.drawPath(maskPath, backgroundPaint);

    // 4. วาดขอบมุม 4 ด้าน (เหมือนเดิม)
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final path = Path();
    // มุมบนซ้าย
    path.moveTo(cutOutRect.left, cutOutRect.top + borderLength);
    path.lineTo(cutOutRect.left, cutOutRect.top + borderRadius);
    path.quadraticBezierTo(
      cutOutRect.left,
      cutOutRect.top,
      cutOutRect.left + borderRadius,
      cutOutRect.top,
    );
    path.lineTo(cutOutRect.left + borderLength, cutOutRect.top);

    // มุมบนขวา
    path.moveTo(cutOutRect.right - borderLength, cutOutRect.top);
    path.lineTo(cutOutRect.right - borderRadius, cutOutRect.top);
    path.quadraticBezierTo(
      cutOutRect.right,
      cutOutRect.top,
      cutOutRect.right,
      cutOutRect.top + borderRadius,
    );
    path.lineTo(cutOutRect.right, cutOutRect.top + borderLength);

    // มุมล่างขวา
    path.moveTo(cutOutRect.right, cutOutRect.bottom - borderLength);
    path.lineTo(cutOutRect.right, cutOutRect.bottom - borderRadius);
    path.quadraticBezierTo(
      cutOutRect.right,
      cutOutRect.bottom,
      cutOutRect.right - borderRadius,
      cutOutRect.bottom,
    );
    path.lineTo(cutOutRect.right - borderLength, cutOutRect.bottom);

    // มุมล่างซ้าย
    path.moveTo(cutOutRect.left + borderLength, cutOutRect.bottom);
    path.lineTo(cutOutRect.left + borderRadius, cutOutRect.bottom);
    path.quadraticBezierTo(
      cutOutRect.left,
      cutOutRect.bottom,
      cutOutRect.left,
      cutOutRect.bottom - borderRadius,
    );
    path.lineTo(cutOutRect.left, cutOutRect.bottom - borderLength);

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
