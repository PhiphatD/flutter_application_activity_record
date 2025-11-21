import 'dart:convert';
import 'dart:math'; // Import Math เพื่อหา Min/Max
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../profile/profile_screen.dart';
import 'package:flutter_application_activity_record/theme/app_colors.dart';
import 'reward_detail_screen.dart';
import 'redeemed_detail_screen.dart';

// Enums for Sorting
enum SortOption { none, pointsLowHigh, pointsHighLow }

// Models
class RewardItem {
  final String id;
  final String name;
  final int pointsCost;
  final int stock;
  final String? imageUrl;
  final String description;
  final String category;

  RewardItem({
    required this.id,
    required this.name,
    required this.pointsCost,
    required this.stock,
    this.imageUrl,
    required this.description,
    this.category = 'General',
  });

  factory RewardItem.fromJson(Map<String, dynamic> json) {
    return RewardItem(
      id: json['id'],
      name: json['name'],
      pointsCost: json['pointCost'],
      stock: json['stock'],
      imageUrl: json['image'],
      description: json['description'],
      category: json['category'] ?? 'General',
    );
  }
}

class RedeemedItem {
  final String id;
  final String prizeName;
  final int pointsCost;
  final DateTime redeemDate;
  final String status;
  final String? imageUrl;
  final String pickupInstruction;

  RedeemedItem({
    required this.id,
    required this.prizeName,
    required this.pointsCost,
    required this.redeemDate,
    required this.status,
    this.imageUrl,
    this.pickupInstruction = "Contact HR",
  });

  factory RedeemedItem.fromJson(Map<String, dynamic> json) {
    return RedeemedItem(
      id: json['redeemId'],
      prizeName: json['prizeName'],
      pointsCost: json['pointCost'],
      redeemDate: DateTime.parse(json['redeemDate']),
      status: json['status'],
      imageUrl: json['image'],
      pickupInstruction: json['pickupInstruction'] ?? "Contact HR",
    );
  }
}

class RewardScreen extends StatefulWidget {
  const RewardScreen({super.key});

  @override
  State<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends State<RewardScreen> {
  final String baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";

  int _userPoints = 0;
  String _userName = "Loading...";
  bool _isLoading = true;

  List<RewardItem> _allRewards = [];
  List<RedeemedItem> _myRedemptions = [];

  // --- Filter & Sort State ---
  bool _showRedeemed = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  List<String> _selectedCategories = [];
  List<String> _availableCategories = ['General', 'Voucher', 'Gadget', 'Food'];

  // [NEW] Dynamic Point Range & Sort
  double _minPointDb = 0; // ค่าต่ำสุดจริงจาก DB
  double _maxPointDb = 10000; // ค่าสูงสุดจริงจาก DB
  RangeValues _currentPointRange = const RangeValues(0, 10000);
  SortOption _selectedSort = SortOption.none;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
    _fetchInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final empId = prefs.getString('empId') ?? '';
      final name = prefs.getString('name') ?? 'Employee';

      final rewardsRes = await http.get(Uri.parse('$baseUrl/rewards'));
      final historyRes = await http.get(
        Uri.parse('$baseUrl/my-redemptions/$empId'),
      );

      if (rewardsRes.statusCode == 200) {
        final List rData = json.decode(utf8.decode(rewardsRes.bodyBytes));
        _allRewards = rData.map((e) => RewardItem.fromJson(e)).toList();

        // [NEW] Calculate Dynamic Range & Categories
        if (_allRewards.isNotEmpty) {
          // 1. Categories
          final cats = _allRewards.map((e) => e.category).toSet().toList();
          if (cats.isNotEmpty) _availableCategories = cats;

          // 2. Points Range
          final points = _allRewards
              .map((e) => e.pointsCost.toDouble())
              .toList();
          double minP = points.reduce(min);
          double maxP = points.reduce(max);

          // เผื่อกรณี min=max
          if (minP == maxP) {
            minP = 0;
            maxP = maxP + 100;
          }

          _minPointDb = minP;
          _maxPointDb = maxP;
          _currentPointRange = RangeValues(_minPointDb, _maxPointDb);
        }
      }

      if (historyRes.statusCode == 200) {
        final List hData = json.decode(utf8.decode(historyRes.bodyBytes));
        _myRedemptions = hData.map((e) => RedeemedItem.fromJson(e)).toList();
      }

      // Mock Points Logic (Temporary)
      int points = 0;
      if (empId == 'E0004')
        points = 1500;
      else if (empId == 'E0005')
        points = 850;
      else if (empId == 'E0006')
        points = 300;
      else
        points = 0;

      if (mounted) {
        setState(() {
          _userName = name;
          _userPoints = points;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching rewards: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onRedeem(RewardItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final empId = prefs.getString('empId') ?? '';

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rewards/redeem'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'emp_id': empId, 'prize_id': item.id}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final remaining = data['remaining_points'];

        setState(() {
          _userPoints = remaining;
          _showRedeemed = true;
        });

        _fetchInitialData();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Redeem Successful!"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final err = jsonDecode(utf8.decode(response.bodyBytes));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err['detail'] ?? "Failed"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // [UPDATED] Logic กรองและเรียงลำดับ
  List<RewardItem> _getFilteredRewards() {
    var list = _allRewards.where((item) {
      // 1. Search
      if (_searchQuery.isNotEmpty) {
        if (!item.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }
      // 2. Category
      if (_selectedCategories.isNotEmpty) {
        if (!_selectedCategories.contains(item.category)) {
          return false;
        }
      }
      // 3. [NEW] Point Range
      if (item.pointsCost < _currentPointRange.start ||
          item.pointsCost > _currentPointRange.end) {
        return false;
      }
      return true;
    }).toList();

    // 4. [NEW] Sorting
    if (_selectedSort == SortOption.pointsLowHigh) {
      list.sort((a, b) => a.pointsCost.compareTo(b.pointsCost));
    } else if (_selectedSort == SortOption.pointsHighLow) {
      list.sort((a, b) => b.pointsCost.compareTo(a.pointsCost));
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: employeeBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomAppBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _fetchInitialData,
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(child: _buildLoyaltyCard()),
                          SliverToBoxAdapter(child: _buildSearchAndFilter()),
                          SliverToBoxAdapter(child: _buildViewSwitcher()),

                          _showRedeemed
                              ? _buildRedeemedSliverList()
                              : _buildAvailableSliverGrid(),

                          const SliverToBoxAdapter(child: SizedBox(height: 80)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoyaltyCard() {
    final pointsText = NumberFormat.decimalPattern().format(_userPoints);
    final expiryText = "31/12/${DateTime.now().year}";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Container(
        height: 180,
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/images/bgcredit.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black38, BlendMode.darken),
          ),
          borderRadius: BorderRadius.circular(20.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Grow Perks Card",
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
                const Icon(Icons.wifi, color: Colors.white54, size: 20),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  pointsText,
                  style: GoogleFonts.poppins(
                    fontSize: 40,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      const Shadow(
                        blurRadius: 10,
                        color: Colors.black45,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "PTS",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "CARD HOLDER",
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: Colors.white60,
                      ),
                    ),
                    Text(
                      _userName.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "VALID THRU",
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: Colors.white60,
                      ),
                    ),
                    Text(
                      expiryText,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // [UPDATED] Search & Filter Bar
  Widget _buildSearchAndFilter() {
    bool isFilterActive =
        _selectedCategories.isNotEmpty ||
        _selectedSort != SortOption.none ||
        _currentPointRange.start != _minPointDb ||
        _currentPointRange.end != _maxPointDb;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search rewards...',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _showFilterModal,
            child: Container(
              height: 45,
              width: 45,
              decoration: BoxDecoration(
                color: isFilterActive ? const Color(0xFF4A80FF) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: isFilterActive
                        ? const Color(0xFF4A80FF).withOpacity(0.3)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.tune_rounded,
                color: isFilterActive ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // [UPDATED] Advanced Filter Modal
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Filter & Sort",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedCategories.clear();
                            _selectedSort = SortOption.none;
                            _currentPointRange = RangeValues(
                              _minPointDb,
                              _maxPointDb,
                            );
                          });
                          setStateModal(() {});
                        },
                        child: Text(
                          "Reset",
                          style: GoogleFonts.poppins(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Sort Options
                  Text(
                    "Sort By",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: [
                      ChoiceChip(
                        label: const Text("Points: Low to High"),
                        selected: _selectedSort == SortOption.pointsLowHigh,
                        onSelected: (val) => setStateModal(
                          () => _selectedSort = val
                              ? SortOption.pointsLowHigh
                              : SortOption.none,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text("Points: High to Low"),
                        selected: _selectedSort == SortOption.pointsHighLow,
                        onSelected: (val) => setStateModal(
                          () => _selectedSort = val
                              ? SortOption.pointsHighLow
                              : SortOption.none,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Point Range Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Points Range",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        "${_currentPointRange.start.toInt()} - ${_currentPointRange.end.toInt()} pts",
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF4A80FF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: _currentPointRange,
                    min: _minPointDb,
                    max: _maxPointDb,
                    divisions: (_maxPointDb - _minPointDb) > 0 ? 20 : 1,
                    activeColor: const Color(0xFF4A80FF),
                    labels: RangeLabels(
                      _currentPointRange.start.round().toString(),
                      _currentPointRange.end.round().toString(),
                    ),
                    onChanged: (RangeValues values) {
                      setStateModal(() => _currentPointRange = values);
                    },
                  ),
                  const SizedBox(height: 20),

                  // Categories
                  Text(
                    "Category",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableCategories.map((cat) {
                      final isSelected = _selectedCategories.contains(cat);
                      return FilterChip(
                        label: Text(cat),
                        selected: isSelected,
                        selectedColor: const Color(0xFFE6EFFF),
                        checkmarkColor: const Color(0xFF4A80FF),
                        onSelected: (val) {
                          setState(() {
                            if (val)
                              _selectedCategories.add(cat);
                            else
                              _selectedCategories.remove(cat);
                          });
                          setStateModal(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {}); // Trigger rebuild on main screen
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A80FF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Apply Filters",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildViewSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Expanded(child: _buildSwitchButton("Rewards", !_showRedeemed)),
            Expanded(child: _buildSwitchButton("History", _showRedeemed)),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchButton(String text, bool isActive) {
    return GestureDetector(
      onTap: () {
        if ((text == "Rewards" && _showRedeemed) ||
            (text == "History" && !_showRedeemed)) {
          setState(() => _showRedeemed = !_showRedeemed);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF4A80FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: isActive ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableSliverGrid() {
    final filteredRewards = _getFilteredRewards();

    if (filteredRewards.isEmpty) {
      return const SliverToBoxAdapter(
        child: _EmptyState(message: "No rewards match your filter."),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16.0,
          crossAxisSpacing: 16.0,
          // [FIX] Adjusted Child Aspect Ratio to prevent overflow on small screens
          childAspectRatio: 0.65,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = filteredRewards[index];
          return _RewardItemCard(
            item: item,
            userPoints: _userPoints,
            onTap: () => _navigateToRewardDetail(item),
          );
        }, childCount: filteredRewards.length),
      ),
    );
  }

  Widget _buildRedeemedSliverList() {
    if (_myRedemptions.isEmpty) {
      return const SliverToBoxAdapter(
        child: _EmptyState(message: "You haven't redeemed anything yet."),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _RedeemedItemCard(
              item: _myRedemptions[index],
              onTap: () => _openRedeemedDetail(_myRedemptions[index]),
            ),
          );
        }, childCount: _myRedemptions.length),
      ),
    );
  }

  void _navigateToRewardDetail(RewardItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RewardDetailScreen(
          rewardName: item.name,
          pointsCost: item.pointsCost,
          description: item.description,
          imageUrls: item.imageUrl != null ? [item.imageUrl!] : [],
          category: item.category,
          stock: item.stock,
          userPoints: _userPoints,
          onRedeem: () => _onRedeem(item),
        ),
      ),
    );
  }

  void _openRedeemedDetail(RedeemedItem item) {
    final List<String> images = item.imageUrl != null ? [item.imageUrl!] : [];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RedeemedDetailScreen(
          redeemId: item.id,
          name: item.prizeName,
          pointsCost: item.pointsCost,
          category: "Reward",
          redeemedAt: item.redeemDate,
          description: "Reward redemption",
          imageUrls: images,
          status: item.status,
          pickupLocation: item.pickupInstruction,
          // [NEW] ส่ง Logic การยกเลิกเข้าไป
          onCancel: () => _onCancelRedeem(item),
        ),
      ),
    );
  }

  // [NEW] ฟังก์ชันเรียก API Cancel
  Future<void> _onCancelRedeem(RedeemedItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final empId = prefs.getString('empId') ?? '';

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rewards/cancel'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'emp_id': empId, 'redeem_id': item.id}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _userPoints = data['remaining_points'];
        });
        _fetchInitialData(); // Refresh list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Cancelled & Refunded"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to cancel redemption"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print("Cancel Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildCustomAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Rewards',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF375987),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            ),
            child: const CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=12'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 50, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(message, style: GoogleFonts.poppins(color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}

class _RewardItemCard extends StatelessWidget {
  final RewardItem item;
  final int userPoints;
  final VoidCallback onTap;

  const _RewardItemCard({
    required this.item,
    required this.userPoints,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final canRedeem = item.stock > 0 && userPoints >= item.pointsCost;
    final isOutOfStock = item.stock <= 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    item.imageUrl != null
                        ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                        : Container(
                            color: Colors.grey[100],
                            child: const Icon(Icons.image, color: Colors.grey),
                          ),
                    if (isOutOfStock)
                      Container(
                        color: Colors.black54,
                        child: Center(
                          child: Text(
                            "SOLD OUT",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // [FIX] Overflow: Use Flexible/TextOverflow
                        Text(
                          item.name,
                          style: GoogleFonts.kanit(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isOutOfStock ? Colors.grey : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.pointsCost} pts',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isOutOfStock
                                ? Colors.grey
                                : const Color(0xFF4A80FF),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? Colors.grey.shade100
                            : (canRedeem
                                  ? const Color(0xFFE6F6E7)
                                  : Colors.orange.shade50),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isOutOfStock
                              ? Colors.transparent
                              : (canRedeem
                                    ? Colors.green.shade200
                                    : Colors.orange.shade200),
                        ),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isOutOfStock
                                ? "Out of Stock"
                                : (canRedeem ? "Redeem" : "Need Points"),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isOutOfStock
                                  ? Colors.grey
                                  : (canRedeem
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700),
                            ),
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
      ),
    );
  }
}

class _RedeemedItemCard extends StatelessWidget {
  final RedeemedItem item;
  final VoidCallback onTap;
  const _RedeemedItemCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 60,
                height: 60,
                child: item.imageUrl != null
                    ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey[100],
                        child: const Icon(Icons.card_giftcard),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.prizeName,
                    style: GoogleFonts.kanit(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    DateFormat('d MMM y, HH:mm').format(item.redeemDate),
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "-${item.pointsCost}",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: item.status == 'Pending'
                        ? Colors.orange.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.status,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: item.status == 'Pending'
                          ? Colors.orange.shade800
                          : Colors.green.shade800,
                      fontWeight: FontWeight.bold,
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
}
