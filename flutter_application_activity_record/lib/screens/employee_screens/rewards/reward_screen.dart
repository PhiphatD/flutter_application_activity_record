import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../widgets/employee_header.dart';
import 'package:flutter_application_activity_record/theme/app_colors.dart';
import 'reward_detail_screen.dart';
import 'redeemed_detail_screen.dart';

// Enums
enum SortOption { none, pointsLowHigh, pointsHighLow }

// --- MODELS ---
class RewardItem {
  final String id;
  final String name;
  final int pointsCost;
  final int stock;
  final List<String> images; // [CHANGED] เปลี่ยนเป็น List
  final String description;
  final String category;
  final String prizeType;

  RewardItem({
    required this.id,
    required this.name,
    required this.pointsCost,
    required this.stock,
    required this.images, // [CHANGED]
    required this.description,
    this.category = 'General',
    required this.prizeType,
  });

  factory RewardItem.fromJson(Map<String, dynamic> json) {
    // 1. Handle Prize Type
    final dynamic rawPrizeType = json['prizeType'] ?? json['prize_type'];
    String finalPrizeType = 'Physical';
    if (rawPrizeType != null && rawPrizeType.toString().trim().isNotEmpty) {
      String cleanedType = rawPrizeType.toString().toUpperCase().trim();
      if (cleanedType == 'DIGITAL') {
        finalPrizeType = 'Digital';
      } else if (cleanedType == 'PRIVILEGE') {
        finalPrizeType = 'Privilege';
      }
    }

    // 2. [NEW] Handle Images List (ส่วนสำคัญที่ทำให้รูปขึ้น)
    List<String> imgList = [];

    // เช็คว่า Backend ส่ง images (List) มาไหม
    if (json['images'] != null) {
      if (json['images'] is List) {
        imgList = List<String>.from(json['images']);
      } else if (json['images'] is String) {
        // เผื่อ Server ส่งมาเป็น JSON String
        try {
          List<dynamic> parsed = jsonDecode(json['images']);
          imgList = parsed.map((e) => e.toString()).toList();
        } catch (_) {}
      }
    }

    // Fallback: ถ้าไม่มี List ให้ลองดู field เก่า 'image'
    if (imgList.isEmpty &&
        json['image'] != null &&
        json['image'].toString().isNotEmpty) {
      imgList.add(json['image'].toString());
    }

    return RewardItem(
      id: json['id'],
      name: json['name'],
      pointsCost: json['pointCost'],
      stock: json['stock'],
      images: imgList, // [CHANGED] ส่ง List เข้าไป
      description: json['description'] ?? '-',
      category: json['category'] ?? 'General',
      prizeType: finalPrizeType,
    );
  }

  // [NEW] Getter สำหรับดึงรูปปก (รูปแรก)
  String get coverImage {
    if (images.isNotEmpty && images.first.isNotEmpty) {
      return images.first;
    }
    return '';
  }

  List<String> get tags {
    List<String> t = [];
    if (stock <= 5 && stock > 0) t.add('HOT');
    if (pointsCost >= 5000) t.add('PREMIUM');
    if (pointsCost <= 500) t.add('BEST SELLER');
    if (id.codeUnitAt(id.length - 1) % 2 == 0) t.add('NEW');
    return t;
  }
}

class RedeemedItem {
  final String id;
  final String prizeName;
  final int pointsCost;
  final DateTime redeemDate;
  final String status;
  final List<String> images;
  final String pickupInstruction;

  RedeemedItem({
    required this.id,
    required this.prizeName,
    required this.pointsCost,
    required this.redeemDate,
    required this.status,
    required this.images,
    this.pickupInstruction = "Contact HR",
  });

  factory RedeemedItem.fromJson(Map<String, dynamic> json) {
    // Parsing Images Logic
    List<String> imgList = [];
    if (json['images'] != null && json['images'] is List) {
      imgList = List<String>.from(json['images']);
    } else if (json['image'] != null) {
      imgList.add(json['image'].toString());
    }

    return RedeemedItem(
      id: json['redeemId'],
      prizeName: json['prizeName'],
      pointsCost: json['pointCost'],
      redeemDate: DateTime.parse(json['redeemDate']),
      status: json['status'],
      images: imgList, // [CHANGED]
      pickupInstruction: json['pickupInstruction'] ?? "Contact HR",
    );
  }

  String get coverImage => images.isNotEmpty ? images.first : '';
}

class RewardScreen extends StatefulWidget {
  const RewardScreen({super.key});

  @override
  State<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends State<RewardScreen>
    with SingleTickerProviderStateMixin {
  final String baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";

  int _userPoints = 0;
  String _userName = "Loading...";
  bool _isLoading = true;

  List<RewardItem> _allRewards = [];
  List<RedeemedItem> _myRedemptions = [];

  // UI State
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // [NEW] Filter Logic: English Labels
  String _selectedFilterType = "All";
  final List<Map<String, dynamic>> _filterOptions = [
    {"label": "All", "value": "All", "icon": Icons.grid_view_rounded},
    {
      "label": "Coupon",
      "value": "Digital",
      "icon": Icons.local_activity_rounded,
    }, // Digital -> Coupon
    {
      "label": "Item",
      "value": "Physical",
      "icon": Icons.card_giftcard_rounded,
    }, // Physical -> Item
    {
      "label": "Privilege",
      "value": "Privilege",
      "icon": Icons.workspace_premium_rounded,
    },
  ];

  double _minPointDb = 0;
  double _maxPointDb = 10000;
  RangeValues _currentPointRange = const RangeValues(0, 10000);
  SortOption _selectedSort = SortOption.none;

  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
    _fetchInitialData();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  // ... (Logic _getColorForPoints, _getTierColor, _connectWebSocket, _fetchInitialData, _onRedeem, _onCancelRedeem ยังเหมือนเดิม) ...
  // เพื่อความกระชับ ผมจะใส่เฉพาะส่วนที่เปลี่ยน Logic หรือจำเป็น

  Color _getColorForPoints(double currentVal) {
    if (_maxPointDb <= _minPointDb) return const Color(0xFF4B5563);
    double percentage =
        (currentVal - _minPointDb) / (_maxPointDb - _minPointDb);
    if (percentage <= 0.33)
      return const Color(0xFF4B5563);
    else if (percentage <= 0.66)
      return const Color(0xFF2563EB);
    else
      return const Color(0xFFD97706);
  }

  Color _getTierColor(int points) {
    double percentage = (points - _minPointDb) / (_maxPointDb - _minPointDb);
    if (percentage <= 0.33)
      return const Color(0xFF4B5563);
    else if (percentage <= 0.66)
      return const Color(0xFF2563EB);
    else
      return const Color(0xFFD97706);
  }

  void _connectWebSocket() {
    try {
      final wsUrl = Uri.parse(
        'ws://numerably-nonevincive-kyong.ngrok-free.dev/ws',
      );
      _channel = WebSocketChannel.connect(wsUrl);
      _channel!.stream.listen((message) {
        if (message == "REFRESH_REWARDS") _fetchInitialData();
      });
    } catch (e) {
      print("WS Error: $e");
    }
  }

  Future<void> _fetchInitialData() async {
    if (_allRewards.isEmpty) setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final empId = prefs.getString('empId') ?? '';
      final name = prefs.getString('name') ?? 'Employee';

      // 1. Profile
      final profileRes = await http.get(Uri.parse('$baseUrl/employees/$empId'));
      if (profileRes.statusCode == 200) {
        final pData = jsonDecode(utf8.decode(profileRes.bodyBytes));
        _userPoints = pData['TOTAL_POINTS'] ?? 0;
      }

      // 2. Rewards
      final rewardsRes = await http.get(Uri.parse('$baseUrl/rewards'));
      if (rewardsRes.statusCode == 200) {
        final List rData = json.decode(utf8.decode(rewardsRes.bodyBytes));
        _allRewards = rData.map((e) => RewardItem.fromJson(e)).toList();

        if (_allRewards.isNotEmpty) {
          final pList = _allRewards
              .map((e) => e.pointsCost.toDouble())
              .toList();
          double minP = pList.reduce(min);
          double maxP = pList.reduce(max);
          if (minP == maxP) maxP += 100;
          _minPointDb = minP;
          _maxPointDb = maxP;
          // [MODIFIED] ปรับการตั้งค่า Range ให้ถูกต้องตาม Min/Max ที่คำนวณได้
          _currentPointRange = RangeValues(_minPointDb, _maxPointDb);
        }
      }

      // 3. History
      final historyRes = await http.get(
        Uri.parse('$baseUrl/my-redemptions/$empId'),
      );
      if (historyRes.statusCode == 200) {
        final List hData = json.decode(utf8.decode(historyRes.bodyBytes));
        _myRedemptions = hData.map((e) => RedeemedItem.fromJson(e)).toList();
      }

      if (mounted) {
        setState(() {
          _userName = name;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error: $e");
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
        setState(() {
          _userPoints = data['remaining_points'];
          _tabController.animateTo(1);
        }); // Auto switch tab
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

  void _onCancelRedeem(RedeemedItem item) async {
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
        setState(() => _userPoints = data['remaining_points']);
        _fetchInitialData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cancelled & Refunded"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  List<RewardItem> _getFilteredRewards() {
    var list = _allRewards.where((item) {
      if (_searchQuery.isNotEmpty) {
        if (!item.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          return false;
      }
      if (_selectedFilterType != "All") {
        final itemType = item.prizeType.toLowerCase().trim();
        final filterType = _selectedFilterType.toLowerCase().trim();
        if (itemType != filterType) return false;
      }
      if (item.pointsCost < _currentPointRange.start ||
          item.pointsCost > _currentPointRange.end) {
        return false;
      }
      return true;
    }).toList();

    if (_selectedSort == SortOption.pointsLowHigh)
      list.sort((a, b) => a.pointsCost.compareTo(b.pointsCost));
    else if (_selectedSort == SortOption.pointsHighLow)
      list.sort((a, b) => b.pointsCost.compareTo(a.pointsCost));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            EmployeeHeader(
              title: "Hello, Employee!",
              subtitle: "Redeem your points",
              searchController: _searchController,
              searchHint: "Find rewards...",
              onFilterTap: _showFilterModal,
              onRefresh: _fetchInitialData,
            ),
            // [NEW] TabBar เหมือนหน้า Todo
            _buildTabBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: Rewards (Marketplace)
                        RefreshIndicator(
                          onRefresh: _fetchInitialData,
                          child: _buildMarketplaceTab(),
                        ),
                        // Tab 2: History
                        RefreshIndicator(
                          onRefresh: _fetchInitialData,
                          child: _buildHistoryTab(),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // [NEW] TabBar Widget (Style match with TodoScreen)
  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF4A80FF),
        unselectedLabelColor: Colors.grey[500],
        indicatorColor: const Color(0xFF4A80FF),
        indicatorWeight: 3,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.normal,
        ),
        tabs: const [
          Tab(text: "Rewards"),
          Tab(text: "History"),
        ],
      ),
    );
  }

  // [NEW] Tab 1 Content
  Widget _buildMarketplaceTab() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildLoyaltyCard()),
        // SliverToBoxAdapter(child: _buildSearchAndFilter()), // Removed as it's in header now
        SliverToBoxAdapter(child: _buildFilterChips()), // Chips are now here
        _buildAvailableSliverGrid(),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  // [NEW] Tab 2 Content
  Widget _buildHistoryTab() {
    if (_myRedemptions.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          _EmptyState(message: "No history yet."),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _myRedemptions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _RedeemedItemCard(
          item: _myRedemptions[index],
          onTap: () => _openRedeemedDetail(_myRedemptions[index]),
        );
      },
    );
  }

  // ... (UI Components: AppBar, LoyaltyCard, Search, Filters, Modal, Grids)

  Widget _buildLoyaltyCard() {
    final pointsText = NumberFormat.decimalPattern().format(_userPoints);
    final expiryText = "31/12/${DateTime.now().year}";
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/images/bgcredit.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black45, BlendMode.darken),
          ),
          borderRadius: BorderRadius.circular(24.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
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
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
                const Icon(Icons.nfc, color: Colors.white54, size: 28),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "AVAILABLE BALANCE",
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      pointsText,
                      style: GoogleFonts.spaceMono(
                        fontSize: 42,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "PTS",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFFFFD700),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
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
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: Colors.white60,
                      ),
                    ),
                    Text(
                      _userName.toUpperCase(),
                      style: GoogleFonts.spaceMono(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "VALID THRU",
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: Colors.white60,
                      ),
                    ),
                    Text(
                      expiryText,
                      style: GoogleFonts.spaceMono(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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

  Widget _buildFilterChips() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(top: 16, bottom: 16),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _filterOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final option = _filterOptions[index];
          final isSelected = _selectedFilterType == option['value'];
          return ChoiceChip(
            avatar: Icon(
              option['icon'],
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            label: Text(option['label']),
            selected: isSelected,
            onSelected: (val) =>
                setState(() => _selectedFilterType = option['value']),
            selectedColor: const Color(0xFF4A80FF),
            labelStyle: GoogleFonts.poppins(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? Colors.transparent : Colors.grey.shade300,
              ),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  Widget _buildAvailableSliverGrid() {
    final filteredRewards = _getFilteredRewards();
    if (filteredRewards.isEmpty)
      return const SliverToBoxAdapter(
        child: _EmptyState(message: "No rewards found."),
      );
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16.0,
          crossAxisSpacing: 16.0,
          childAspectRatio: 0.57,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = filteredRewards[index];
          return _RewardItemCard(
            item: item,
            userPoints: _userPoints,
            priceColor: _getTierColor(item.pointsCost),
            onTap: () => _navigateToRewardDetail(item),
          );
        }, childCount: filteredRewards.length),
      ),
    );
  }

  // ... (Modal Filter: Use previous code, it is correct)
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            Color dynamicColor = _getColorForPoints(_currentPointRange.end);
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
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
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
                  const SizedBox(height: 20),
                  Text(
                    "Sort By",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: [
                      ChoiceChip(
                        label: const Text("Low to High"),
                        selected: _selectedSort == SortOption.pointsLowHigh,
                        onSelected: (val) => setStateModal(
                          () => _selectedSort = val
                              ? SortOption.pointsLowHigh
                              : SortOption.none,
                        ),
                        selectedColor: const Color(0xFF4A80FF),
                        labelStyle: GoogleFonts.poppins(
                          color: _selectedSort == SortOption.pointsLowHigh
                              ? Colors.white
                              : Colors.black87,
                        ),
                        backgroundColor: Colors.white,
                      ),
                      ChoiceChip(
                        label: const Text("High to Low"),
                        selected: _selectedSort == SortOption.pointsHighLow,
                        onSelected: (val) => setStateModal(
                          () => _selectedSort = val
                              ? SortOption.pointsHighLow
                              : SortOption.none,
                        ),
                        selectedColor: const Color(0xFF4A80FF),
                        labelStyle: GoogleFonts.poppins(
                          color: _selectedSort == SortOption.pointsHighLow
                              ? Colors.white
                              : Colors.black87,
                        ),
                        backgroundColor: Colors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Points Range",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: GoogleFonts.spaceMono(
                          color: dynamicColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        child: Text(
                          "${_currentPointRange.start.toInt()} - ${_currentPointRange.end.toInt()}",
                        ),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: _currentPointRange,
                    min: _minPointDb,
                    max: _maxPointDb,
                    divisions: (_maxPointDb - _minPointDb) > 0 ? 20 : 1,
                    activeColor: dynamicColor,
                    inactiveColor: Colors.grey.shade200,
                    onChanged: (RangeValues values) =>
                        setStateModal(() => _currentPointRange = values),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A80FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        "Apply",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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

  void _navigateToRewardDetail(RewardItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RewardDetailScreen(
          rewardName: item.name,
          pointsCost: item.pointsCost,
          description: item.description,
          imageUrls: item.images, // [CHANGED] ส่ง List ทั้งหมดไป
          category: item.category,
          stock: item.stock,
          userPoints: _userPoints,
          onRedeem: () => _onRedeem(item),
        ),
      ),
    );
  }

  void _openRedeemedDetail(RedeemedItem item) {
    final images = item.images;
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
          onCancel: () => _onCancelRedeem(item),
        ),
      ),
    );
  }
}

// ... (EmptyState, RewardItemCard, RedeemedItemCard คงเดิม) ...
class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 60, color: Colors.grey[300]),
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
  final Color priceColor;

  const _RewardItemCard({
    required this.item,
    required this.userPoints,
    required this.onTap,
    required this.priceColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOutOfStock = item.stock <= 0;
    final bool canRedeem = !isOutOfStock && userPoints >= item.pointsCost;
    double progress = (!canRedeem && !isOutOfStock)
        ? (userPoints / item.pointsCost).clamp(0.0, 1.0)
        : 0.0;
    final tags = item.tags;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: item.coverImage.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: item.coverImage,
                            fit: BoxFit.cover,
                            memCacheWidth: 300,
                            placeholder: (context, url) =>
                                Container(color: Colors.grey[100]),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                            ),
                          )
                        : Container(
                            color: Colors.grey[100],
                            child: const Icon(Icons.image, color: Colors.grey),
                          ),
                  ),
                  if (isOutOfStock)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "SOLD OUT",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!isOutOfStock && tags.isNotEmpty)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: tags
                            .take(2)
                            .map((tag) => _buildTag(tag))
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.category.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[400],
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.name,
                          style: GoogleFonts.kanit(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isOutOfStock
                                ? Colors.grey
                                : const Color(0xFF1F2937),
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.pointsCost} pts',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: isOutOfStock ? Colors.grey : priceColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (isOutOfStock)
                          Container(
                            height: 4,
                            width: 30,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          )
                        else if (canRedeem)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4A80FF), Color(0xFF2E5BFF)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF4A80FF,
                                  ).withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              "Redeem",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.grey[100],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.orange.shade300,
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${(progress * 100).toInt()}% to goal",
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.orange.shade800,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    Color bg;
    Color fg = Colors.white;
    IconData? icon;
    switch (text) {
      case 'HOT':
        bg = Colors.red;
        icon = Icons.local_fire_department;
        break;
      case 'NEW':
        bg = Colors.blue;
        icon = Icons.new_releases;
        break;
      case 'PREMIUM':
        bg = Colors.black87;
        icon = Icons.diamond;
        break;
      case 'BEST SELLER':
        bg = const Color(0xFFFFD700);
        fg = Colors.black87;
        icon = Icons.emoji_events;
        break;
      default:
        bg = Colors.grey;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
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
    Color statusBg;
    Color statusText;
    switch (item.status.toLowerCase()) {
      case 'pending':
        statusBg = Colors.orange.shade50;
        statusText = Colors.orange.shade800;
        break;
      case 'cancelled':
        statusBg = Colors.red.shade50;
        statusText = Colors.red.shade800;
        break;
      default:
        statusBg = Colors.green.shade50;
        statusText = Colors.green.shade800;
        break;
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 70,
                height: 70,
                child: item.coverImage.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.coverImage,
                        fit: BoxFit.cover,
                      )
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
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Requested: ${DateFormat('d MMM y, HH:mm').format(item.redeemDate)}",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.status,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              item.status == 'Cancelled' ? "Refunded" : "-${item.pointsCost}",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: item.status == 'Cancelled'
                    ? Colors.grey
                    : Colors.red.shade300,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
