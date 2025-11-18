import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
// removed external bottom sheet import; implement local confirm bottom sheet

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
    if (widget.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This reward is out of stock', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (widget.userPoints < widget.pointsCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient points. You need ${widget.pointsCost} points', style: GoogleFonts.poppins()),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Confirm Redemption', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(widget.rewardName, style: GoogleFonts.poppins()),
              const SizedBox(height: 4),
              Text('Cost: ${widget.pointsCost} points', style: GoogleFonts.poppins(color: Colors.grey[700])),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.poppins())),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                      widget.onRedeem();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A80FF)),
                    child: Text('Confirm', style: GoogleFonts.poppins(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canRedeem = widget.stock > 0 && widget.userPoints >= widget.pointsCost;
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: Stack(
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          itemCount: widget.imageUrls.length,
                          itemBuilder: (context, index) {
                            return Container(
                              width: double.infinity,
                              height: 300,
                              decoration: BoxDecoration(
                                image: DecorationImage(image: NetworkImage(widget.imageUrls[index]), fit: BoxFit.cover),
                              ),
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
                                effect: const ExpandingDotsEffect(dotHeight: 8, dotWidth: 8, activeDotColor: Colors.white, dotColor: Colors.white54),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Text(widget.rewardName, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFF4A80FF).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF4A80FF).withOpacity(0.3))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.monetization_on, color: Colors.amber[600], size: 16),
                        const SizedBox(width: 4),
                        Text('${widget.pointsCost} pts', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF4A80FF))),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)), child: Text(widget.category, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]))),
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: widget.stock > 0 ? Colors.green[50] : Colors.red[50], borderRadius: BorderRadius.circular(12)), child: Text('Stock: ${widget.stock}', style: GoogleFonts.poppins(fontSize: 12, color: widget.stock > 0 ? Colors.green[600] : Colors.red[600]))),
                  ]),
                  const SizedBox(height: 20),
                  Text('Description', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 8),
                  Text(widget.description, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600], height: 1.5)),
                  const SizedBox(height: 20),
                  Text('Terms & Conditions', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildTermItem('• Valid for 30 days from redemption'),
                    _buildTermItem('• Cannot be exchanged for cash'),
                    _buildTermItem('• Limited to one per customer'),
                    _buildTermItem('• Subject to availability'),
                  ]),
                  const SizedBox(height: 30),
                  Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)), child: Row(children: [
                    Icon(Icons.account_balance_wallet, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Your Points', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                      Text('${widget.userPoints} points', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ])),
                    if (widget.userPoints < widget.pointsCost)
                      Text('Need ${widget.pointsCost - widget.userPoints} more', style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange[600])),
                  ])),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))]),
        child: ElevatedButton(
          onPressed: canRedeem ? _handleRedeem : null,
          style: ElevatedButton.styleFrom(backgroundColor: canRedeem ? const Color(0xFF4A80FF) : Colors.grey[300], padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.card_giftcard, color: canRedeem ? Colors.amber[600] : Colors.grey[500], size: 20),
            const SizedBox(width: 8),
            Text(canRedeem ? 'Redeem for ${widget.pointsCost} points' : widget.stock <= 0 ? 'Out of Stock' : 'Insufficient Points', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: canRedeem ? Colors.white : Colors.grey[600])),
          ]),
        ),
      ),
    );
  }

  Widget _buildTermItem(String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(text, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])));
  }
}