import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'profile_screen.dart';
import 'reward_detail_screen.dart';
import 'redeemed_detail_screen.dart';

class _RewardItem {
  final String id;
  final String name;
  final int pointsCost;
  final String vendorOrCategory;
  int stock;
  final DateTime expiryDate;
  final String? imageUrl;
  final List<String> imageUrls;
  final String description;

  _RewardItem({
    required this.id,
    required this.name,
    required this.pointsCost,
    required this.vendorOrCategory,
    required this.stock,
    required this.expiryDate,
    this.imageUrl,
    this.imageUrls = const [],
    required this.description,
  });
}

class _RedeemedItem {
  final String id;
  final String name;
  final int pointsCost;
  final String vendorOrCategory;
  final DateTime redeemedAt;
  final String? sourceRewardId;
  final String? description;
  final List<String> imageUrls;

  _RedeemedItem({
    required this.id,
    required this.name,
    required this.pointsCost,
    required this.vendorOrCategory,
    required this.redeemedAt,
    this.sourceRewardId,
    this.description,
    this.imageUrls = const [],
  });
}

class RewardScreen extends StatefulWidget {
  const RewardScreen({super.key});

  @override
  State<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends State<RewardScreen> {
  int _userPoints = 1250;
  bool _showRedeemed = false;
  String _searchText = '';
  String _userName = 'Phiphat Deepee';

  final List<_RewardItem> _availableRewards = [
    _RewardItem(
      id: 'r1',
      name: 'Starbucks eVoucher 100 THB',
      pointsCost: 300,
      vendorOrCategory: 'Voucher',
      stock: 15,
      expiryDate: DateTime.now().add(const Duration(days: 30)),
      imageUrls: [
        'https://images.unsplash.com/photo-1511920170033-f8396924c348?auto=format&fit=crop&w=800&q=80',
        'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=800&q=80',
        'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=800&q=80',
      ],
      description:
          'บัตรกำนัลใช้ได้ทุกสาขา ภายใน 30 วัน สามารถใช้ได้กับเครื่องดื่มและขนมทุกชนิด',
    ),
    _RewardItem(
      id: 'r2',
      name: 'Amazon Gift Card 500 THB',
      pointsCost: 1200,
      vendorOrCategory: 'Shopping',
      stock: 8,
      expiryDate: DateTime.now().add(const Duration(days: 60)),
      imageUrls: [
        'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?auto=format&fit=crop&w=800&q=80',
        'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?auto=format&fit=crop&w=800&q=80',
      ],
      description:
          'บัตรของขวัญ Amazon มูลค่า 500 บาท สามารถใช้ซื้อสินค้าได้ทุกประเภท',
    ),
    _RewardItem(
      id: 'r3',
      name: 'Food Court Coupon 50 THB',
      pointsCost: 200,
      vendorOrCategory: 'Food',
      stock: 0,
      expiryDate: DateTime.now().add(const Duration(days: 15)),
      imageUrl:
          'https://images.unsplash.com/photo-1551218808-94e220e084d2?auto=format&fit=crop&w=800&q=80',
      description:
          'คูปองใช้ได้ที่โรงอาหารในบริษัท สามารถใช้ได้กับร้านค้าที่ร่วมรายการ',
    ),
    _RewardItem(
      id: 'r4',
      name: 'Movie Ticket',
      pointsCost: 350,
      vendorOrCategory: 'Entertainment',
      stock: 12,
      expiryDate: DateTime.now().add(const Duration(days: 45)),
      imageUrls: [
        'https://images.unsplash.com/photo-1594909122845-11baa439b7bf?auto=format&fit=crop&w=800&q=80',
        'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=800&q=80',
        'https://images.unsplash.com/photo-1536440136628-849c177e76a1?auto=format&fit=crop&w=800&q=80',
      ],
      description: 'ตั๋วภาพยนตร์ 1 ที่นั่ง สามารถใช้ได้กับภาพยนตร์ทุกเรื่อง',
    ),
  ];

  final List<_RedeemedItem> _redeemedRewards = [
    _RedeemedItem(
      id: 'rd1',
      name: 'Movie Ticket',
      pointsCost: 250,
      vendorOrCategory: 'Voucher',
      redeemedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  List<_RewardItem> get _filteredAvailableRewards {
    if (_searchText.isEmpty) return _availableRewards;
    return _availableRewards
        .where((r) => r.name.toLowerCase().contains(_searchText.toLowerCase()))
        .toList();
  }

  List<_RedeemedItem> get _filteredRedeemedRewards {
    if (_searchText.isEmpty) return _redeemedRewards;
    return _redeemedRewards
        .where((r) => r.name.toLowerCase().contains(_searchText.toLowerCase()))
        .toList();
  }

  void _redeemReward(_RewardItem item) {
    final canRedeem = item.stock > 0 && _userPoints >= item.pointsCost;
    if (!canRedeem) return;

    // Process the redemption
    setState(() {
      _userPoints -= item.pointsCost;
      item.stock -= 1;
      _redeemedRewards.insert(
        0,
        _RedeemedItem(
          id: 'rd_${item.id}_${DateTime.now().millisecondsSinceEpoch}',
          name: item.name,
          pointsCost: item.pointsCost,
          vendorOrCategory: item.vendorOrCategory,
          redeemedAt: DateTime.now(),
          sourceRewardId: item.id,
          description: item.description,
          imageUrls: item.imageUrls.isNotEmpty
              ? item.imageUrls
              : (item.imageUrl != null ? [item.imageUrl!] : []),
        ),
      );
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Successfully redeemed ${item.name}!',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _navigateToRewardDetail(_RewardItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RewardDetailScreen(
          rewardName: item.name,
          pointsCost: item.pointsCost,
          description: item.description,
          imageUrls: item.imageUrls.isNotEmpty
              ? item.imageUrls
              : (item.imageUrl != null ? [item.imageUrl!] : []),
          category: item.vendorOrCategory,
          stock: item.stock,
          userPoints: _userPoints,
          onRedeem: () {
            _redeemReward(item);
            // Switch to redeemed view after successful redemption
            if (mounted) {
              setState(() {
                _showRedeemed = true;
              });
            }
          },
        ),
      ),
    ).then((_) {
      // Update user points when returning from detail screen
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomAppBar(),
            _buildLoyaltyCard(),
            _buildViewSwitcher(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: _showRedeemed
                    ? _buildRedeemedList()
                    : _buildAvailableList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoyaltyCard() {
    final pointsText = NumberFormat.decimalPattern().format(_userPoints);
    final expiryText = DateFormat(
      'MM/yy',
    ).format(DateTime.now().add(const Duration(days: 180)));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/images/bgcredit.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black26, BlendMode.darken),
          ),
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _userName,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10.0),
                  Text(
                    'Current Points',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color.fromRGBO(255, 208, 0, 1),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    pointsText,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      color: const Color.fromRGBO(255, 208, 0, 1),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    'Points can be redeemed for rewards',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color.fromARGB(255, 255, 228, 107),
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  Container(height: 1, color: Colors.white.withOpacity(0.4)),
                  const SizedBox(height: 6.0),
                  Text(
                    'Expiry  $expiryText',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12.0),
            Icon(Icons.emoji_events, color: Colors.amber.shade300, size: 56),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            child: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: const NetworkImage(
                'https://i.pravatar.cc/150?img=45',
              ),
            ),
          ),
          Text(
            'Reward',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF375987),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: Colors.black54,
              size: 28,
            ),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderPoints() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: const Color(0x4DE2F3FF),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: const Color.fromRGBO(0, 0, 0, 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Points',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$_userPoints',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF4A80FF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Reward items'),
            labelStyle: TextStyle(
              color: _showRedeemed ? Colors.black87 : Colors.white,
              fontWeight: _showRedeemed ? FontWeight.normal : FontWeight.bold,
            ),
            selected: !_showRedeemed,
            onSelected: (selected) {
              if (selected) setState(() => _showRedeemed = false);
            },
            backgroundColor: Colors.white,
            selectedColor: const Color(0xFF4A80FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
              side: BorderSide(
                color: _showRedeemed
                    ? Colors.grey.shade400
                    : const Color(0xFF4A80FF),
              ),
            ),
            showCheckmark: false,
          ),
          const SizedBox(width: 8.0),
          ChoiceChip(
            label: const Text('Redeemed items'),
            labelStyle: TextStyle(
              color: _showRedeemed ? Colors.white : Colors.black87,
              fontWeight: _showRedeemed ? FontWeight.bold : FontWeight.normal,
            ),
            selected: _showRedeemed,
            onSelected: (selected) {
              if (selected) setState(() => _showRedeemed = true);
            },
            backgroundColor: Colors.white,
            selectedColor: const Color(0xFF4A80FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
              side: BorderSide(
                color: _showRedeemed
                    ? const Color(0xFF4A80FF)
                    : Colors.grey.shade400,
              ),
            ),
            showCheckmark: false,
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableList() {
    final items = _filteredAvailableRewards;
    return GridView.builder(
      itemCount: items.length,
      padding: const EdgeInsets.only(top: 10.0, bottom: 20.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16.0,
        crossAxisSpacing: 16.0,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _RewardItemCard(
          item: item,
          userPoints: _userPoints,
          onTap: () => _navigateToRewardDetail(item),
        );
      },
    );
  }

  Widget _buildRedeemedList() {
    final items = _filteredRedeemedRewards;
    return ListView.builder(
      itemCount: items.length,
      padding: const EdgeInsets.only(top: 10.0, bottom: 20.0),
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: EdgeInsets.only(top: index == 0 ? 0 : 16.0),
          child: InkWell(
            onTap: () => _openRedeemedDetail(item),
            child: _RedeemedItemCard(item: item),
          ),
        );
      },
    );
  }

  void _openRedeemedDetail(_RedeemedItem item) {
    final images = item.imageUrls;
    final desc = item.description;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RedeemedDetailScreen(
          name: item.name,
          pointsCost: item.pointsCost,
          category: item.vendorOrCategory,
          redeemedAt: item.redeemedAt,
          description: desc,
          imageUrls: images,
        ),
      ),
    );
  }
}

class _RewardItemCard extends StatelessWidget {
  final _RewardItem item;
  final int userPoints;
  final VoidCallback onTap;

  const _RewardItemCard({
    super.key,
    required this.item,
    required this.userPoints,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final canRedeem = item.stock > 0 && userPoints >= item.pointsCost;
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: SizedBox(
                width: double.infinity,
                height: 100,
                child: item.imageUrl != null
                    ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                    : Container(color: Colors.grey[300]),
              ),
            ),
            const SizedBox(height: 10.0),
            Text(
              item.name,
              style: GoogleFonts.kanit(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: Colors.black,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4.0),
            Text(
              'Stock: ${item.stock}',
              style: GoogleFonts.kanit(fontSize: 12, color: Colors.black54),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: canRedeem
                      ? const Color(0xFF4A80FF)
                      : Colors.grey[600],
                  side: BorderSide(
                    color: canRedeem
                        ? const Color(0xFF4A80FF)
                        : Colors.grey.shade400,
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                onPressed: onTap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View',
                      style: GoogleFonts.kanit(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    Icon(
                      Icons.visibility_outlined,
                      color: canRedeem
                          ? const Color(0xFF4A80FF)
                          : Colors.grey[600],
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypePill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Text(
        label,
        style: GoogleFonts.kanit(
          color: Colors.black54,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _RedeemedItemCard extends StatelessWidget {
  final _RedeemedItem item;
  const _RedeemedItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: GoogleFonts.kanit(
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 6.0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F6E7),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    '-${item.pointsCost} Points',
                    style: GoogleFonts.kanit(
                      color: const Color(0xFF06A710),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.grey),
            const SizedBox(height: 8.0),
            Row(
              children: [
                const Icon(
                  Icons.category_outlined,
                  color: Colors.black,
                  size: 20,
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    item.vendorOrCategory,
                    style: GoogleFonts.kanit(fontSize: 14, color: Colors.black),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Row(
              children: [
                const Icon(
                  Icons.event_available_outlined,
                  color: Colors.black,
                  size: 20,
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    'Redeemed : ${DateFormat('d MMM y, HH:mm').format(item.redeemedAt)}',
                    style: GoogleFonts.kanit(fontSize: 14, color: Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                _buildTypePill('TYPE: ${item.vendorOrCategory}'),
                const Spacer(),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.grey[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    onPressed: null,
                    child: Text(
                      'Redeemed',
                      style: GoogleFonts.kanit(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypePill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Text(
        label,
        style: GoogleFonts.kanit(
          color: Colors.black54,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
