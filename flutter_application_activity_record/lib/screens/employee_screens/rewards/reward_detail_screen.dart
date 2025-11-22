import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:flutter_application_activity_record/widgets/reward_confirmation_bottom_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RewardDetailScreen extends StatefulWidget {
  final String rewardName;
  final int pointsCost;
  final String description;
  final List<String> imageUrls;
  final String category;
  final int stock;
  final int userPoints;
  final Function() onRedeem;

  const RewardDetailScreen({
    super.key,
    required this.rewardName,
    required this.pointsCost,
    required this.description,
    required this.imageUrls,
    required this.category,
    required this.stock,
    required this.userPoints,
    required this.onRedeem,
  });

  @override
  State<RewardDetailScreen> createState() => _RewardDetailScreenState();
}

class _RewardDetailScreenState extends State<RewardDetailScreen> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleRedeem() {
    RewardConfirmationBottomSheet.show(
      context: context,
      rewardName: widget.rewardName,
      pointsCost: widget.pointsCost,
      description: widget.description,
      imageUrl: widget.imageUrls.isNotEmpty ? widget.imageUrls.first : null,
      category: widget.category,
      onConfirm: () {
        Navigator.pop(context); // close bottom sheet
        Navigator.pop(context); // close detail page
        widget.onRedeem();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Logic คำนวณสถานะ
    final bool isOutOfStock = widget.stock <= 0;
    final bool isAffordable = widget.userPoints >= widget.pointsCost;
    final int pointsNeeded = widget.pointsCost - widget.userPoints;
    final double progress = (widget.userPoints / widget.pointsCost).clamp(
      0.0,
      1.0,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // 1. Parallax Image Header
              SliverAppBar(
                expandedHeight: 300,
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
                        itemCount: widget.imageUrls.length,
                        itemBuilder: (context, index) {
                          return CachedNetworkImage(
                            imageUrl: widget.imageUrls[index],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[100],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) {
                              return Container(
                                color: Colors.grey[100],
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                  size: 50,
                                ),
                              );
                            },
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

              // 2. Content Body
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  // [UX] เลื่อนเนื้อหาขึ้นมาทับรูปนิดนึงให้ดู Modern
                  transform: Matrix4.translationValues(0, -20, 0),
                  padding: EdgeInsets.fromLTRB(
                    24,
                    32,
                    24,
                    // [FIXED] เพิ่มพื้นที่ด้านล่างให้มากกว่าความสูงของ Bottom Bar + Safe Area
                    150 + MediaQuery.of(context).padding.bottom,
                  ), // Bottom padding for Sticky Bar
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Category & Stock Badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.category.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          const Spacer(),
                          _buildStockBadge(widget.stock),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        widget.rewardName,
                        style: GoogleFonts.kanit(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2937),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Points Cost (Hero Element)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "${widget.pointsCost}",
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF4A80FF),
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              "points",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      const Divider(height: 1),
                      const SizedBox(height: 24),

                      // Description
                      _buildSectionTitle("Description"),
                      const SizedBox(height: 8),
                      Text(
                        widget.description,
                        style: GoogleFonts.kanit(
                          fontSize: 15,
                          color: Colors.grey[700],
                          height: 1.6,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Terms (Better Layout)
                      _buildSectionTitle("Terms & Conditions"),
                      const SizedBox(height: 12),
                      _buildTermRow(
                        Icons.calendar_today_outlined,
                        "Valid for 30 days after redemption",
                      ),
                      _buildTermRow(
                        Icons.block_outlined,
                        "Non-refundable and cannot be exchanged for cash",
                      ),
                      _buildTermRow(
                        Icons.confirmation_number_outlined,
                        "Show code at counter to claim",
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 3. Sticky Bottom Bar (The Game Changer)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                20 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
                border: const Border(top: BorderSide(color: Color(0xFFF3F4F6))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress Bar (ถ้าแต้มไม่พอ)
                  if (!isAffordable && !isOutOfStock) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "You have ${widget.userPoints} pts",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          "Need $pointsNeeded more",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.orange.shade400,
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: (isAffordable && !isOutOfStock)
                          ? _handleRedeem
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOutOfStock
                            ? Colors.grey[300]
                            : (isAffordable
                                  ? const Color(0xFF4A80FF)
                                  : Colors.grey[200]),
                        foregroundColor: isAffordable
                            ? Colors.white
                            : Colors.grey[500],
                        elevation: (isAffordable && !isOutOfStock) ? 4 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        shadowColor: const Color(0xFF4A80FF).withOpacity(0.4),
                      ),
                      child: Text(
                        isOutOfStock
                            ? "Out of Stock"
                            : (isAffordable
                                  ? "Redeem Now"
                                  : "Not Enough Points"),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockBadge(int stock) {
    Color color;
    String text;

    if (stock <= 0) {
      color = Colors.red;
      text = "Out of Stock";
    } else if (stock < 10) {
      color = Colors.orange;
      text = "Only $stock left!";
    } else {
      color = Colors.green;
      text = "In Stock";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF111827),
      ),
    );
  }

  Widget _buildTermRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.grey[700]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}
