import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ActivityCard extends StatefulWidget {
  final String type;
  final String title;
  final String location;
  final String organizer;
  final int points;
  final int currentParticipants;
  final int maxParticipants;
  final bool isCompulsory;

  const ActivityCard({
    super.key,
    required this.type,
    required this.title,
    required this.location,
    required this.organizer,
    required this.points,
    required this.currentParticipants,
    required this.maxParticipants,
    this.isCompulsory = false,
  });

  @override
  State<ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<ActivityCard>
    with SingleTickerProviderStateMixin {
  bool _isFavorited = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorited = !_isFavorited;
    });

    _animationController.forward().then((_) {
      _animationController.reverse();
    });
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'training':
        return Icons.model_training;
      case 'seminar':
        return Icons.campaign_outlined;
      case 'workshop':
        return Icons.construction;
      default:
        return Icons.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color secondaryTextColor = Colors.black54;
    const Color cardBackgroundColor = Colors.white;

    return Stack(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16.0),
          decoration: BoxDecoration(
            color: cardBackgroundColor,
            border: Border.all(
              color: const Color.fromRGBO(0, 0, 0, 0.2),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 4.0,
                offset: const Offset(0, 4),
              ),
            ],
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                print('Tapped on: ${widget.title}');
              },
              borderRadius: BorderRadius.circular(20.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: GoogleFonts.kanit(
                                  fontWeight: FontWeight.w400,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 40), // Space for the icon
                      ],
                    ),

                    const Divider(color: Colors.grey),
                    const SizedBox(height: 8.0),
                    _buildInfoRow(
                      icon: Icons.location_on_outlined,
                      text: widget.location,
                    ),
                    const SizedBox(height: 8.0),
                    _buildInfoRow(
                      icon: Icons.person_outline,
                      text: 'Organizers : ${widget.organizer}',
                    ),
                    const SizedBox(height: 8.0),
                    _buildInfoRow(
                      icon: Icons.star_border_purple500_outlined,
                      text: 'Points : ${widget.points}',
                    ),
                    const SizedBox(height: 8.0),
                    Row(
                      children: [
                        _buildTypePill(widget.type),
                        const Spacer(),
                        const Icon(
                          Icons.people_alt_outlined,
                          color: secondaryTextColor,
                          size: 20,
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          '${widget.currentParticipants}/${widget.maxParticipants}',
                          style: GoogleFonts.kanit(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 5,
          right: 8,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: IconButton(
              icon: Icon(
                _isFavorited ? Icons.favorite : Icons.favorite_border,
                color: _isFavorited ? Colors.red : Colors.grey,
                size: 24,
              ),
              onPressed: _toggleFavorite,
            ),
          ),
        ),
      ],
    );
  }

  // Helper widget for info rows
  Widget _buildInfoRow({required String text, IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: Colors.black, size: 22),
          const SizedBox(width: 12.0),
        ],
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.kanit(
              fontWeight: FontWeight.w400,
              fontSize: 14,
              color: Colors.black,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // --- Widget ย่อยสำหรับแถวที่มีข้อมูลด้านขวา (เช่น ผู้เข้าร่วม) ---
  Widget _buildInfoRowWithTrailing({
    required IconData icon,
    required Color iconColor,
    required String text,
    required String trailingText,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 22.0),
        const SizedBox(width: 12.0),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.kanit(
              fontWeight: FontWeight.w400,
              fontSize: 14,
              color: Colors.black,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(width: 12.0),
        Text(
          trailingText,
          style: GoogleFonts.kanit(
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  // --- Widget ย่อยสำหรับป้าย Type ---
  Widget _buildTypePill(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Text(
        'TYPE: $type',
        style: GoogleFonts.kanit(
          color: Colors.black54,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
