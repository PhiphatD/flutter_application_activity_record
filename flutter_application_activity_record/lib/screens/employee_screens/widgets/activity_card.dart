import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../activities/activity_detail_screen.dart';

class ActivityCard extends StatelessWidget {
  final String id;
  final String type;
  final String title;
  final String location;
  final String organizer;
  final int points;
  final int currentParticipants;
  final int maxParticipants;
  final bool isCompulsory;
  final String status;
  final bool isFavorite;
  final bool isRegistered;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onTap; // [NEW] Callback for card tap

  const ActivityCard({
    super.key,
    required this.id,
    required this.type,
    required this.title,
    required this.location,
    required this.organizer,
    required this.points,
    required this.currentParticipants,
    required this.maxParticipants,
    this.isCompulsory = false,
    this.status = 'Open',
    this.isFavorite = false,
    this.isRegistered = false,
    this.onToggleFavorite,
    this.onTap, // [NEW]
  });

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'training':
        return const Color(0xFF4A80FF); // Blue
      case 'seminar':
        return const Color(0xFFFF9F1C); // Orange
      case 'workshop':
        return const Color(0xFF2EC4B6); // Teal
      default:
        return const Color(0xFF9E9E9E); // Grey
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor(type);
    final bool isFull = currentParticipants >= maxParticipants;

    Color statusColor;
    Color statusBg;
    String statusText;

    if (isRegistered) {
      statusColor = Colors.green.shade700;
      statusBg = Colors.green.shade50;
      statusText = "Registered";
    } else {
      switch (status) {
        case 'Joined':
          statusColor = Colors.green.shade700;
          statusBg = Colors.green.shade50;
          statusText = "Registered";
          break;
        case 'Missed':
          statusColor = Colors.red.shade700;
          statusBg = Colors.red.shade50;
          statusText = "Missed";
          break;
        case 'Upcoming':
          statusColor = Colors.orange.shade800;
          statusBg = Colors.orange.shade50;
          statusText = "Upcoming";
          break;
        case 'Full':
          statusColor = Colors.red;
          statusBg = Colors.red.shade50;
          statusText = "Full";
          break;
        default: // Open
          if (isCompulsory) {
            statusColor = Colors.orange.shade900;
            statusBg = Colors.orange.shade50;
            statusText = "Mandatory";
          } else {
            statusColor = Colors.blue.shade700;
            statusBg = Colors.blue.shade50;
            statusText = "Join Now";
          }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          // Use external onTap if provided, else default navigation
          onTap:
              onTap ??
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ActivityDetailScreen(activityId: id),
                  ),
                );
              },
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 6, color: typeColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                type.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: typeColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isCompulsory)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.red.shade100,
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.lock_outline,
                                      size: 10,
                                      color: Colors.red.shade700,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      "REQUIRED",
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const Spacer(),
                            // Heart Icon with GestureDetector
                            GestureDetector(
                              onTap: onToggleFavorite,
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(
                                  isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 22,
                                  color: isFavorite
                                      ? Colors.red
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: GoogleFonts.kanit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "$location  |  $organizer",
                                style: GoogleFonts.kanit(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.group_outlined,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "$currentParticipants/$maxParticipants",
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: maxParticipants > 0
                                          ? currentParticipants /
                                                maxParticipants
                                          : 0,
                                      backgroundColor: Colors.grey.shade100,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isFull ? Colors.red : typeColor,
                                      ),
                                      minHeight: 3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: statusColor.withOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                statusText,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
