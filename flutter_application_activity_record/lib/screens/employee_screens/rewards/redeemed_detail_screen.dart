import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../widgets/custom_confirm_dialog.dart';
import '../../../widgets/auto_close_success_dialog.dart';

class RedeemedDetailScreen extends StatefulWidget {
  final String redeemId;
  final String name;
  final int pointsCost;
  final String category;
  final DateTime redeemedAt;
  final String? description;
  final List<String> imageUrls;
  final String status;
  final String pickupLocation;
  final String contactInfo;
  final VoidCallback? onCancel;

  // [NEW] Fields for Smart Ticket
  final String prizeType; // Physical, Digital, Privilege
  final String? voucherCode;
  final DateTime? usageExpiredDate;

  const RedeemedDetailScreen({
    super.key,
    required this.redeemId,
    required this.name,
    required this.pointsCost,
    required this.category,
    required this.redeemedAt,
    this.description,
    this.imageUrls = const [],
    this.status = 'Pending',
    this.pickupLocation = 'HR Department, Floor 2',
    this.contactInfo = 'Contact Admin',
    this.onCancel,
    // [NEW] Default values
    this.prizeType = 'Physical',
    this.voucherCode,
    this.usageExpiredDate,
  });

  @override
  State<RedeemedDetailScreen> createState() => _RedeemedDetailScreenState();
}

class _RedeemedDetailScreenState extends State<RedeemedDetailScreen> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Copied '$text'"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleCancel() async {
    // 1. ถามยืนยัน พร้อมรายละเอียด
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => CustomConfirmDialog.danger(
        title: "Cancel Redemption?",
        subtitle:
            "Return '${widget.name}'?\n\nYou will get ${widget.pointsCost} points back.",
        confirmText: "Yes, Refund",
        // [เพิ่มส่วนนี้ครับ]
        onConfirm: () {
          Navigator.pop(context, true); // ปิด Dialog และบอกว่า "ตกลง (true)"
        },
      ),
    );

    // ถ้าไม่ได้กดตกลง (กดนอกกรอบ หรือกด Cancel) ก็จบการทำงาน
    if (confirm != true) return;

    // 2. Loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final empId = prefs.getString('empId') ?? '';

      // ใช้ Config.apiUrl หรือ Hardcode ตามสะดวก
      const baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";

      final response = await http.post(
        Uri.parse('$baseUrl/rewards/cancel'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'emp_id': empId, 'redeem_id': widget.redeemId}),
      );

      // ปิด Loading
      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        // 3. สำเร็จ -> โชว์ Auto Close Dialog
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const AutoCloseSuccessDialog(
              title: "Refund Successful",
              subtitle: "Points returned.",
              icon: Icons.replay_circle_filled_rounded,
              color: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // 4. เรียก Callback เพื่อบอกหน้าแม่ให้ Refresh
        if (widget.onCancel != null) {
          widget.onCancel!();
        }

        // 5. ปิดหน้า Detail กลับไป
        if (mounted) Navigator.pop(context);
      } else {
        throw Exception("Failed to cancel");
      }
    } catch (e) {
      // กรณี Error ปิด Loading ก่อน
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // 1. App Bar
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: Colors.white,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: widget.imageUrls.isNotEmpty
                  ? Image.network(widget.imageUrls[0], fit: BoxFit.cover)
                  : Container(color: Colors.grey[200]),
            ),
          ),

          // 2. Smart Ticket Content
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // --- TICKET CONTAINER ---
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // --- HEADER INFO ---
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
                            child: Column(
                              children: [
                                _buildStatusBadge(), // [NEW] Helper
                                const SizedBox(height: 24),
                                Text(
                                  widget.name,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.kanit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Used ${widget.pointsCost} Points",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          _buildTicketDivider(), // Dashed Line
                          // --- ADAPTIVE BODY (เปลี่ยนตาม Type) ---
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(20),
                              ),
                            ),
                            child: _buildTicketBody(), // [ADDED] ฟังก์ชันนี้
                          ),
                        ],
                      ),
                    ),

                    // Cancel Button (เฉพาะ Physical/Digital ที่ยังไม่ได้รับของ/โค้ด)
                    if (widget.status == 'Pending') ...[
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _handleCancel,
                          icon: const Icon(
                            Icons.cancel_outlined,
                            color: Colors.red,
                          ),
                          label: Text(
                            "Cancel Redemption",
                            style: GoogleFonts.poppins(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red.shade200),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // [ADDED] ฟังก์ชันสร้างตั๋วตามประเภท (Adaptive Ticket Body)
  Widget _buildTicketBody() {
    // 1. Privilege (วันลา/สิทธิพิเศษ)
    if (widget.prizeType == 'Privilege') {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFF7ED),
            ), // Orange bg
            child: const Icon(
              Icons.workspace_premium,
              size: 50,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Privilege Activated",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Show this screen to HR/Admin",
            style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 24),
          if (widget.usageExpiredDate != null)
            _buildInfoRow(
              Icons.event_busy,
              "Valid Until",
              DateFormat('d MMMM y').format(widget.usageExpiredDate!),
            ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.domain_verification,
            "Status",
            "Auto-Applied to System",
          ),
        ],
      );
    }

    // 2. Digital Voucher (คูปอง)
    if (widget.prizeType == 'Digital') {
      // Case A: Pending (ยังไม่ได้โค้ด)
      if (widget.status == 'Pending') {
        return Column(
          children: [
            const Icon(
              Icons.hourglass_top_rounded,
              size: 60,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              "Waiting for Code",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Admin will send you the code shortly.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            _buildInfoRow(Icons.support_agent, "Contact", widget.contactInfo),
          ],
        );
      }
      // Case B: Completed (ได้โค้ดแล้ว)
      return Column(
        children: [
          Text(
            "VOUCHER CODE",
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _copyToClipboard(widget.voucherCode ?? ""),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4), // Light Green bg
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.voucherCode ?? "ERROR-CODE",
                    style: GoogleFonts.sourceCodePro(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.copy, color: Colors.green, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (widget.usageExpiredDate != null)
            Text(
              "Expires on: ${DateFormat('d MMM y').format(widget.usageExpiredDate!)}",
              style: GoogleFonts.poppins(
                color: Colors.red.shade400,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 24),
          _buildInfoRow(
            Icons.info_outline,
            "Instruction",
            widget.pickupLocation, // ใช้ field นี้เก็บวิธีใช้
          ),
        ],
      );
    }

    // 3. Physical (ของชิ้น) - Default
    final bool isPending = widget.status == 'Pending';
    if (!isPending) {
      // Completed
      return Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 60,
            color: Colors.green.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            "Received",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Enjoy your reward!",
            style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      );
    }
    // Pending
    return Column(
      children: [
        Text(
          "Scan to Pickup",
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[400],
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        QrImageView(
          data: "ACTION:PICKUP|ID:${widget.redeemId}",
          version: QrVersions.auto,
          size: 180.0,
          backgroundColor: Colors.white,
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _copyToClipboard(widget.redeemId),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Ticket ID: ${widget.redeemId}",
                style: GoogleFonts.sourceCodePro(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.copy, size: 14, color: Colors.grey),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildInfoRow(
          Icons.store_mall_directory_outlined,
          "Pickup Location",
          widget.pickupLocation,
        ),
      ],
    );
  }

  Widget _buildTicketDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 0),
      child: Row(
        children: List.generate(
          30,
          (index) => Expanded(
            child: Container(
              color: index % 2 == 0 ? Colors.transparent : Colors.grey[300],
              height: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color bg = Colors.grey.shade100;
    Color text = Colors.grey.shade700;

    if (widget.status == 'Pending') {
      bg = Colors.orange.shade50;
      text = Colors.orange.shade800;
    } else if (widget.status == 'Completed' || widget.status == 'Received') {
      bg = Colors.green.shade50;
      text = Colors.green.shade800;
    } else if (widget.status == 'Cancelled') {
      bg = Colors.red.shade50;
      text = Colors.red.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        widget.status,
        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: text),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF375987), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.kanit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1F2937),
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
