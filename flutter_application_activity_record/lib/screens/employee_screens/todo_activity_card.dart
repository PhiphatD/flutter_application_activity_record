import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'activity_detail_screen.dart';

// 1. (เหมือนเดิม) enum สำหรับสถานะของกิจกรรม
enum ActivityStatus {
  upcoming, // กำลังจะมาถึง
  attended, // เข้าร่วมแล้ว
  unattended, // ขาดเข้าร่วม
}

// 2. (เหมือนเดิม) ActivityCard Widget
class ActivityCard extends StatelessWidget {
  final String id;
  final String type;
  final String title;
  final String location;
  final String organizer;
  final int points;
  final ActivityStatus status;

  // (Dummy data - ไม่ได้ใช้ในหน้านี้ แต่รับค่ามาเพื่อให้สอดคล้องกับ constructor)
  final int currentParticipants;
  final int maxParticipants;

  const ActivityCard({
    Key? key,
    required this.id,
    required this.type,
    required this.title,
    required this.location,
    required this.organizer,
    required this.points,
    required this.status,
    required this.currentParticipants,
    required this.maxParticipants,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // (เหมือนเดิม) กำหนดสีขอบตามสถานะ
    Color borderColor = Colors.white;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActivityDetailScreen(activityId: id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 3. (แก้ไข) แถวบนสุด ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.kanit(
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // (แก้ไข) ส่ง points เข้าไปใน _buildStatusPill
                _buildStatusPill(status, points),
              ],
            ),
            const Divider(color: Colors.grey),
            const SizedBox(height: 12),
            // (เหมือนเดิม) สถานที่
            _buildInfoRow(icon: Icons.location_on_outlined, text: location),
            const SizedBox(height: 8),
            // --- 4. (แก้ไข) แถวล่างสุด ---
            _buildInfoRow(
              icon: Icons.person_outline,
              text: 'Organizers : $organizer',
            ),
            const SizedBox(height: 8),
            // (เหมือนเดิม) แถวล่างสุด: Type (เช่น Training, Workshop)
            _buildInfoRow(
              icon: Icons.star_border_purple500_outlined,
              text: 'Points : $points',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildTypePill(type),
                const Spacer(),
                const Icon(
                  Icons.people_alt_outlined,
                  color: Colors.black54,
                  size: 20,
                ),
                const SizedBox(width: 4.0),
                Text(
                  '$currentParticipants/$maxParticipants',
                  style: GoogleFonts.kanit(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

  // (เหมือนเดิม) ป้าย Type (เช่น Training, Workshop)
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
        style: const TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  // --- 5. (แก้ไข) เมธอดสร้างป้ายสถานะ (รับ points) ---
  Widget _buildStatusPill(ActivityStatus status, int points) {
    String label;
    Color bgColor;
    Color textColor;
    Widget content;

    switch (status) {
      // (แก้ไข) กรณีเข้าร่วมแล้ว: แสดงคะแนน
      case ActivityStatus.attended:
        label = '+$points P.'; // <--- เปลี่ยนเป็นคะแนน
        bgColor = const Color(0xFFE6F6E7); // Light green
        textColor = const Color(0xFF06A710); // Dark green
        content = Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        );
        break;

      // (เหมือนเดิม) กรณีขาดเข้าร่วม
      case ActivityStatus.unattended:
        label = 'Unattended';
        bgColor = const Color(0xFFFBE7E7); // Light red
        textColor = const Color(0xFFD91A1A); // Dark red
        content = Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        );
        break;

      // (เหมือนเดิม) กรณีกำลังจะมาถึง
      case ActivityStatus.upcoming:
      default:
        label = 'Upcoming';
        bgColor = const Color(0xFFE6EFFF); // Light blue
        textColor = const Color(0xFF4A80FF); // Dark blue
        content = Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        );
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: content,
    );
  }

  // --- 6. (ลบ) เมธอด _buildPointsText ---
  // (เมธอดนี้ถูกลบออกไปทั้งหมด)
}
