import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class RedeemedDetailScreen extends StatefulWidget {
  final String name;
  final int pointsCost;
  final String category;
  final DateTime redeemedAt;
  final String? description;
  final List<String> imageUrls;

  const RedeemedDetailScreen({
    super.key,
    required this.name,
    required this.pointsCost,
    required this.category,
    required this.redeemedAt,
    this.description,
    this.imageUrls = const [],
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

  @override
  Widget build(BuildContext context) {
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
                          itemCount: widget.imageUrls.isEmpty
                              ? 1
                              : widget.imageUrls.length,
                          itemBuilder: (context, index) {
                            if (widget.imageUrls.isEmpty) {
                              return Container(color: Colors.grey[300]);
                            }
                            return Container(
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: NetworkImage(widget.imageUrls[index]),
                                  fit: BoxFit.cover,
                                ),
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
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.name,
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F6E7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.monetization_on,
                                color: const Color(0xFF06A710),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.pointsCost} pts',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF06A710),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.category,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Redeemed: ${DateFormat('d MMM y, HH:mm').format(widget.redeemedAt)}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Description',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.description ?? 'No description',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.grey[600],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Redeemed',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
