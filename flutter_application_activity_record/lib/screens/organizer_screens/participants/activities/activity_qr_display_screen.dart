import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ActivityQrDisplayScreen extends StatefulWidget {
  final String activityName;
  final String actId;
  final String qrData;
  final String timeInfo;

  const ActivityQrDisplayScreen({
    super.key,
    required this.activityName,
    required this.actId,
    required this.qrData,
    required this.timeInfo,
  });

  @override
  State<ActivityQrDisplayScreen> createState() =>
      _ActivityQrDisplayScreenState();
}

class _ActivityQrDisplayScreenState extends State<ActivityQrDisplayScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSaving = false;

  Future<void> _saveQrImage() async {
    setState(() => _isSaving = true);

    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }

    final Uint8List? image = await _screenshotController.capture();

    if (image != null) {
      await Gal.putImageBytes(image, name: "GrowPerks_${widget.actId}");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("QR Code saved to Gallery!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
    setState(() => _isSaving = false);
  }

  Future<void> _shareQrImage() async {
    final Uint8List? image = await _screenshotController.capture();
    if (image != null) {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = await File('${directory.path}/qr_temp.png').create();
      await imagePath.writeAsBytes(image);

      await Share.shareXFiles([
        XFile(imagePath.path),
      ], text: 'Check-in QR for ${widget.activityName}');
    }
  }

  @override
  Widget build(BuildContext context) {
    // [UPDATED] ดึงขนาดหน้าจอ
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 80, 0, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    // [UPDATED] ปรับความกว้างให้ Responsive (85% ของจอ, ไม่เกิน 350px)
                    width: screenSize.width * 0.85,
                    constraints: const BoxConstraints(
                      maxWidth: 350,
                      minWidth: 280,
                    ),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.event_available,
                              color: Color(0xFF0083B0),
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Activity Check-in",
                              style: GoogleFonts.kanit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0083B0),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 30),

                        // [UPDATED] ใช้ FittedBox กันชื่อยาวเกิน
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.activityName,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.kanit(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        QrImageView(
                          data: widget.qrData,
                          version: QrVersions.auto,
                          size: 220.0,
                          // ใส่ Logo ตรงกลาง (Optional)
                          // embeddedImage: const NetworkImage('...'),
                        ),

                        const SizedBox(height: 24),
                        Text(
                          "Scan to check-in",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "Check-in Time: ${widget.timeInfo}",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "ID: ${widget.actId}",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: Icons.share,
                        label: "Share",
                        onTap: _shareQrImage,
                      ),
                      _buildActionButton(
                        icon: Icons.download,
                        label: "Save",
                        onTap: _saveQrImage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.kanit(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }
}
