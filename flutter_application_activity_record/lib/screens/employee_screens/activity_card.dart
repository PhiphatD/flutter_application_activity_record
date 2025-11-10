import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ActivityCard extends StatelessWidget {
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
    const Color defaultBorderColor = Color.fromRGBO(0, 0, 0, 0.2);
    const Color secondaryTextColor = Colors.black54;
    const Color cardBackgroundColor = Colors.white;

    return Container(
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
            print('Tapped on: $title');
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
                            title,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4.0),
                const Divider(color: Colors.grey),
                const SizedBox(height: 4.0),
                _buildInfoRow(icon: Icons.location_on_outlined, text: location),
                const SizedBox(height: 4.0),
                _buildInfoRow(
                  icon: Icons.person_outline,
                  text: 'Organizers : $organizer',
                ),
                const SizedBox(height: 4.0),
                _buildInfoRow(
                  icon: Icons.star_border_purple500_outlined,
                  text: 'Points : $points',
                ),
                const SizedBox(height: 12.0),
                Row(
                  children: [
                    _buildTypePill(type),
                    const Spacer(),
                    const Icon(
                      Icons.people_alt_outlined,
                      color: secondaryTextColor,
                      size: 20,
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      '$currentParticipants/$maxParticipants',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
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
    );
  }

  // Helper widget for info rows
  Widget _buildInfoRow({required String text, IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: Colors.black, size: 25),
          const SizedBox(width: 16.0),
        ],
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w400,
              fontSize: 16,
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
        Icon(icon, color: iconColor, size: 25.0),
        const SizedBox(width: 16.0),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w400,
              fontSize: 16,
              color: Colors.black,
              height: 1.4, // <--- ลดลงเล็กน้อย
            ),
          ),
        ),
        const SizedBox(width: 12.0),
        Text(
          trailingText,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w400,
            fontSize: 16,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  // --- Widget ย่อยสำหรับป้าย Type ---
  Widget _buildTypePill(String type) {
    final Color pillColor = isCompulsory
        ? const Color(0xFFEAA11F).withOpacity(0.7)
        : const Color(0xFFA1C1D6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: pillColor,
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getIconForType(type), size: 16),
          const SizedBox(width: 8.0),
          Text(
            'TYPE : $type',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              fontSize: 12,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
