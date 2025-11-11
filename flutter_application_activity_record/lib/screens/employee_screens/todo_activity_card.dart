import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

// --- 1. (เพิ่ม) สร้าง enum สถานะ ---
enum ActivityStatus {
  upcoming, // ลงทะเบียนแล้ว แต่ยังไม่ถึงวัน
  attended, // เข้าร่วมแล้ว
  unattended, // ไม่ได้เข้าร่วม
}

class ActivityCard extends StatefulWidget {
  final String type; // <--- เรายังเก็บ type ไว้เผื่อใช้กับไอคอน
  final String title;
  final String location;
  final String organizer;
  final int points;
  final int currentParticipants;
  final int maxParticipants;
  final bool isCompulsory;

  // --- 2. (เพิ่ม) Property ใหม่ ---
  final ActivityStatus status;

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
    this.status = ActivityStatus.upcoming, // <-- ค่าเริ่มต้น
  });

  @override
  State<ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<ActivityCard> {
  // --- 3. (ลบ) โค้ด Animation ของหัวใจ ---
  // (ลบ _isFavorited, _animationController, _scaleAnimation, initState, dispose)

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
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: defaultBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: defaultBorderColor.withOpacity(0.5),
            blurRadius: 4.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- ส่วนเนื้อหาหลัก (ซ้าย) ---
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(), // <-- 4. (แก้ไข) เรียก Header ใหม่
                  const SizedBox(height: 12.0),
                  Text(
                    widget.title,
                    // --- 5. (แก้ไข) ลบ GoogleFonts ---
                    style: GoogleFonts.kanit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12.0),
                  _buildInfoRow(
                    icon: Icons.location_on_outlined,
                    text: widget.location,
                    secondaryTextColor: secondaryTextColor,
                  ),
                  const SizedBox(height: 8.0),
                  _buildInfoRow(
                    icon: Icons.person_outline,
                    text: widget.organizer,
                    secondaryTextColor: secondaryTextColor,
                  ),
                ],
              ),
            ),

            // --- เส้นคั่นกลาง (เหมือนเดิม) ---
            const VerticalDivider(
              color: defaultBorderColor,
              thickness: 1.5,
              width: 32.0,
            ),

            // --- ส่วนคะแนน (ขวา) (เหมือนเดิม) ---
            _buildPointsAndParticipants(),
          ],
        ),
      ),
    );
  }

  // --- 6. (แก้ไข) Header ---
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatusPill(), // <-- 7. (แก้ไข) เรียกฟังก์ชันใหม่
        // (ลบปุ่ม Favorite ออก)
      ],
    );
  }

  // (ลบ _buildFavoriteButton() ทั้งฟังก์ชัน)

  Widget _buildInfoRow({
    required IconData icon,
    required String text,
    required Color secondaryTextColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: secondaryTextColor, size: 20.0),
        const SizedBox(width: 12.0),
        Expanded(
          child: Text(
            text,
            // --- 5. (แก้ไข) ลบ GoogleFonts ---
            style: GoogleFonts.kanit(
              fontWeight: FontWeight.w400,
              fontSize: 14,
              color: Colors.black,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  // --- Widget ส่วนคะแนน (ขวา) (เหมือนเดิม) ---
  Widget _buildPointsAndParticipants() {
    final NumberFormat formatter = NumberFormat("#,###");
    return SizedBox(
      width: 70,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${widget.currentParticipants}/${widget.maxParticipants}',
            // --- 5. (แก้ไข) ลบ GoogleFonts ---
            style: GoogleFonts.kanit(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
          ),
          ),  
        ],
      ),
    );
  }

  // --- 8. (เพิ่ม) Widget ย่อยสำหรับป้าย Status (แทนป้าย Type) ---
  Widget _buildStatusPill() {
    String text;
    Color pillColor;
    Color textColor;
    IconData? icon;

    switch (widget.status) {
      case ActivityStatus.attended:
        text = '+${NumberFormat("#,###").format(widget.points)} P.';
        pillColor = const Color(0xFF06A710).withOpacity(0.20); // เขียว
        textColor = const Color(0xFF06A710);
        icon = Icons.check_circle_outline;
        break;
      case ActivityStatus.unattended:
        text = 'Unattended';
        pillColor = const Color(0xFFD91A1A).withOpacity(0.15); // แดง
        textColor = const Color(0xFFD91A1A);
        icon = Icons.cancel_outlined;
        break;
      case ActivityStatus.upcoming:
      default:
        text = 'Upcoming';
        pillColor = const Color(0xFFA1C1D6); // สีฟ้า (เหมือน Type เดิม)
        textColor = Colors.black;
        icon = Icons.schedule; // ไอคอนนาฬิกา
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: pillColor,
        border: Border.all(color: textColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) // แสดงไอคอน
            Icon(icon, size: 14, color: textColor),
          if (icon != null) const SizedBox(width: 6.0),
          Text(
            text,
            // --- 5. (แก้ไข) ลบ GoogleFonts ---
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
