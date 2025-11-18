import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RewardConfirmationBottomSheet extends StatelessWidget {
  final String rewardName;
  final int pointsCost;
  final String description;
  final String? imageUrl;
  final String category;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const RewardConfirmationBottomSheet({
    super.key,
    required this.rewardName,
    required this.pointsCost,
    required this.description,
    this.imageUrl,
    required this.category,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: true,
      child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Reward image and name
          if (imageUrl != null)
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: NetworkImage(imageUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const SizedBox(height: 16),

          Text(
            rewardName,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          // Description section
          _buildSection('Description', description),
          const SizedBox(height: 16),

          // Details section
          _buildSection('Details', ''),
          const SizedBox(height: 8),

          // Spend details
          _buildDetailRow(
            icon: Icons.account_balance_wallet,
            label: 'Spend',
            value: '• $pointsCost points',
            iconColor: Colors.green,
          ),
          const SizedBox(height: 8),

          // Category details
          _buildDetailRow(
            icon: Icons.category,
            label: 'Category',
            value: '• $category',
            iconColor: Colors.amber,
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.grey[400]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A80FF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.monetization_on,
                        color: Colors.amber[600],
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Use $pointsCost',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
        ),
      ],
    );
  }

  static void show({
    required BuildContext context,
    required String rewardName,
    required int pointsCost,
    required String description,
    String? imageUrl,
    required String category,
    required VoidCallback onConfirm,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RewardConfirmationBottomSheet(
        rewardName: rewardName,
        pointsCost: pointsCost,
        description: description,
        imageUrl: imageUrl,
        category: category,
        onConfirm: onConfirm,
        onCancel: () => Navigator.pop(context),
      ),
    );
  }
}
