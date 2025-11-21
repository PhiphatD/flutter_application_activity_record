import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

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
      const SnackBar(
        content: Text("Copied to clipboard"),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _handleCancel() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          "Cancel Redemption",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Are you sure you want to cancel?\nPoints will be refunded to your account.",
          style: GoogleFonts.poppins(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("No", style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.onCancel != null) {
                widget.onCancel!();
                Navigator.pop(context);
              }
            },
            child: Text(
              "Yes, Cancel",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPending = widget.status == 'Pending';
    final String qrData = "ACTION:PICKUP|ID:${widget.redeemId}";
    final DateTime deadline = widget.redeemedAt.add(const Duration(days: 7));
    final String deadlineStr = DateFormat('d MMM y').format(deadline);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
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
              background: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: widget.imageUrls.isEmpty
                        ? 1
                        : widget.imageUrls.length,
                    itemBuilder: (context, index) {
                      if (widget.imageUrls.isEmpty) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.image,
                            size: 50,
                            color: Colors.grey,
                          ),
                        );
                      }
                      return Image.network(
                        widget.imageUrls[index],
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                  if (widget.imageUrls.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: SmoothPageIndicator(
                          controller: _pageController,
                          count: widget.imageUrls.length,
                          effect: const ExpandingDotsEffect(
                            dotHeight: 8,
                            dotWidth: 8,
                            activeDotColor: Colors.white,
                            dotColor: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

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
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                // Status Banner
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isPending
                                        ? const Color(0xFFFFF8E1)
                                        : const Color(0xFFE6F6E7),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isPending
                                          ? Colors.amber.shade200
                                          : Colors.green.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isPending
                                            ? Icons.inventory_2_outlined
                                            : Icons.check_circle,
                                        color: isPending
                                            ? Colors.amber.shade800
                                            : Colors.green.shade800,
                                        size: 20,
                                      ),
                                      const SizedBox(
                                        width: 12,
                                      ), // [FIXED] Increased spacing in Status Banner
                                      Text(
                                        isPending
                                            ? "Ready to Pickup"
                                            : "Completed",
                                        style: GoogleFonts.poppins(
                                          color: isPending
                                              ? Colors.amber.shade900
                                              : Colors.green.shade900,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
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

                          if (isPending) _buildTicketDivider(),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(20),
                              ),
                            ),
                            child: Column(
                              children: [
                                if (isPending) ...[
                                  Text(
                                    "Scan to Pickup",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[400],
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: QrImageView(
                                      data: qrData,
                                      version: QrVersions.auto,
                                      size: 180.0,
                                      backgroundColor: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  InkWell(
                                    onTap: () =>
                                        _copyToClipboard(widget.redeemId),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "Ticket ID: ${widget.redeemId}",
                                          style: GoogleFonts.sourceCodePro(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.copy,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Pick up by: $deadlineStr",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.red.shade400,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),

                                  const SizedBox(height: 24),
                                  // [FIXED] Info Row Spacing
                                  _buildInfoRow(
                                    Icons.store_mall_directory_outlined,
                                    "Pickup Location",
                                    widget.pickupLocation,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInfoRow(
                                    Icons.support_agent,
                                    "Contact",
                                    widget.contactInfo,
                                  ),
                                ] else ...[
                                  // Completed View
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.green.shade50,
                                    ),
                                    child: Icon(
                                      Icons.mark_email_read_outlined,
                                      size: 60,
                                      color: Colors.green.shade300,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "Reward Received",
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "on ${DateFormat('d MMMM y, HH:mm').format(widget.redeemedAt)}",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // [REMOVED] Description Section removed per requirement

                    // Cancel Button
                    if (isPending) ...[
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: TextButton.icon(
                          onPressed: _handleCancel,
                          icon: const Icon(
                            Icons.cancel_outlined,
                            color: Colors.grey,
                          ),
                          label: Text(
                            "Cancel Redemption",
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Points will be fully refunded.",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[400],
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

  Widget _buildTicketDivider() {
    return Stack(
      children: [
        Positioned.fill(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final boxWidth = constraints.constrainWidth();
                const dashWidth = 8.0;
                final dashHeight = 1.0;
                final dashCount = (boxWidth / (2 * dashWidth)).floor();
                return Flex(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  direction: Axis.horizontal,
                  children: List.generate(dashCount, (_) {
                    return SizedBox(
                      width: dashWidth,
                      height: dashHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.grey.shade300),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),
        Container(
          height: 20,
          width: 10,
          decoration: const BoxDecoration(
            color: Color(0xFFF5F7FA),
            borderRadius: BorderRadius.horizontal(right: Radius.circular(10)),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            height: 20,
            width: 10,
            decoration: const BoxDecoration(
              color: Color(0xFFF5F7FA),
              borderRadius: BorderRadius.horizontal(left: Radius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  // [RE-DESIGNED] Enterprise Standard Info Row
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Icon Box
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Icon(icon, color: const Color(0xFF375987), size: 24),
          ),

          const SizedBox(width: 20),

          // 2. Text Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.kanit(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1F2937),
                    height: 1.2,
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
