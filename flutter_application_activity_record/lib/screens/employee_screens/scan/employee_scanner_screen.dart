import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart'; // ต้องเพิ่ม package นี้
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EmployeeScannerScreen extends StatefulWidget {
  const EmployeeScannerScreen({super.key});

  @override
  State<EmployeeScannerScreen> createState() => _EmployeeScannerScreenState();
}

class _EmployeeScannerScreenState extends State<EmployeeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ฟังก์ชันจัดการเมื่อเจอ QR Code
  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        _handleQrCode(barcode.rawValue!);
        break;
      }
    }
  }

  // ฟังก์ชันเลือกรูปจาก Gallery
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isProcessing = true);

      // ใช้ mobile_scanner วิเคราะห์รูปภาพ
      final BarcodeCapture? capture = await _controller.analyzeImage(
        image.path,
      );

      if (capture != null && capture.barcodes.isNotEmpty) {
        final String? code = capture.barcodes.first.rawValue;
        if (code != null) {
          _handleQrCode(code);
        } else {
          _showError("No QR code found in this image.");
        }
      } else {
        _showError("No QR code found.");
      }
    } catch (e) {
      _showError("Error analyzing image: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // Logic การเช็คอิน
  Future<void> _handleQrCode(String qrData) async {
    setState(() => _isProcessing = true);
    _controller.stop(); // หยุดกล้องชั่วคราว

    try {
      // Parse QR Data: "ACTION:CHECKIN|ACT_ID:xxxxx"
      // หรือแบบง่ายที่เป็นแค่ ID กิจกรรม (แล้วแต่ตกลง)
      // สมมติรับแบบ Standard ที่เราออกแบบ: "ACTION:CHECKIN|ACT_ID:A0001"

      String actId = qrData;
      if (qrData.startsWith("ACTION:CHECKIN")) {
        final parts = qrData.split('|');
        for (var part in parts) {
          if (part.startsWith("ACT_ID:")) {
            actId = part.substring(7);
          }
        }
      } else {
        // Fallback กรณี QR เป็นแค่ ID เพียวๆ
        actId = qrData;
      }

      // Call API
      final prefs = await SharedPreferences.getInstance();
      final empId = prefs.getString('empId') ?? '';

      final response = await http.post(
        Uri.parse('https://numerably-nonevincive-kyong.ngrok-free.dev/checkin'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "emp_id": empId,
          "act_id": actId,
          "scanned_by": "self", // ระบุว่าสแกนเอง
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        await _showResultDialog(
          isSuccess: true,
          title: "Check-in Successful!",
          message: "You earned ${data['points_earned']} points.",
        );
        Navigator.pop(context, true); // กลับหน้าหลักพร้อมบอกว่าสำเร็จ
      } else {
        final err = jsonDecode(utf8.decode(response.bodyBytes));
        await _showResultDialog(
          isSuccess: false,
          title: "Check-in Failed",
          message: err['detail'] ?? "Unknown error",
        );
        _controller.start(); // เริ่มกล้องใหม่
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      await _showResultDialog(isSuccess: false, title: "Error", message: "$e");
      _controller.start();
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _showResultDialog({
    required bool isSuccess,
    required String title,
    required String message,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.cancel,
              color: isSuccess ? Colors.green : Colors.red,
              size: 80,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSuccess ? Colors.green : Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("OK", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanWindow = size.width * 0.7;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Overlay
          CustomPaint(
            painter: ScannerOverlayPainter(scanWindow),
            child: Container(),
          ),
          // UI Controls
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
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
                        icon: ValueListenableBuilder(
                          valueListenable:
                              _controller, // [แก้ไข 1] Listen ที่ controller โดยตรง
                          builder: (context, state, child) {
                            // [แก้ไข 2] ดึงค่า torchState จาก state object
                            return Icon(
                              state.torchState == TorchState.on
                                  ? Icons.flash_on
                                  : Icons.flash_off,
                              color: Colors.white,
                              size: 28,
                            );
                          },
                        ),
                        onPressed: () => _controller.toggleTorch(),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Instructions
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Align QR code within the frame",
                    style: GoogleFonts.poppins(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 40),

                // Bottom Action Bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  color: Colors.black.withOpacity(0.6),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: _pickImageFromGallery,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.image,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Scan from Gallery",
                              style: GoogleFonts.poppins(
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
          // Loading Overlay
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// Painter สำหรับวาดกรอบ (Reuse จากไฟล์เดิมได้ หรือใช้อันนี้)
class ScannerOverlayPainter extends CustomPainter {
  final double scanWindow;
  ScannerOverlayPainter(this.scanWindow);

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: scanWindow,
            height: scanWindow,
          ),
          const Radius.circular(20),
        ),
      );

    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Draw background with hole
    canvas.drawPath(
      Path.combine(PathOperation.difference, backgroundPath, cutoutPath),
      backgroundPaint,
    );

    // Draw Corners
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanWindow,
      height: scanWindow,
    );
    final cornerSize = 30.0;

    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.top + cornerSize)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.left + cornerSize, rect.top),
      borderPaint,
    );
    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(rect.right - cornerSize, rect.top)
        ..lineTo(rect.right, rect.top)
        ..lineTo(rect.right, rect.top + cornerSize),
      borderPaint,
    );
    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.bottom - cornerSize)
        ..lineTo(rect.left, rect.bottom)
        ..lineTo(rect.left + cornerSize, rect.bottom),
      borderPaint,
    );
    // Bottom Right
    canvas.drawPath(
      Path()
        ..moveTo(rect.right - cornerSize, rect.bottom)
        ..lineTo(rect.right, rect.bottom)
        ..lineTo(rect.right, rect.bottom - cornerSize),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
