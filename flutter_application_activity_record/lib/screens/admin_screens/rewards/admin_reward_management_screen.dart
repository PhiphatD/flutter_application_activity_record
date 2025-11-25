import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart' hide Config;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../backend_api/config.dart';
import '../../../../services/admin_service.dart';
import 'admin_reward_form_screen.dart';
import '../../../widgets/optimized_network_image.dart';
import '../../organizer_screens/participants/enterprise_scanner_screen.dart';
import '../../../widgets/admin_header.dart';

class AdminRewardManagementScreen extends StatefulWidget {
  const AdminRewardManagementScreen({super.key});

  @override
  State<AdminRewardManagementScreen> createState() =>
      _AdminRewardManagementScreenState();
}

class _AdminRewardManagementScreenState
    extends State<AdminRewardManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AdminService _service = AdminService();

  String _adminId = '';
  // Data State
  List<dynamic>? _allRewards; // เก็บข้อมูลดิบทั้งหมด
  List<dynamic> _filteredRewards = []; // เก็บข้อมูลที่ผ่านการกรองแล้ว
  bool _isLoading = true;

  // Filter State (Inventory Tab)
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";
  String _filterStockStatus = "All"; // All, Low, Out
  String _filterType = "All"; // All, Physical, Digital, Privilege

  // [NEW] Search State (Requests Tab)
  final TextEditingController _requestSearchCtrl = TextEditingController();
  String _requestSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAdminId();
    _tabController.addListener(_handleTabChange);
    // Inventory Search Listener
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.toLowerCase();
        _applyFilters();
      });
    });

    // [NEW] Requests Search Listener
    _requestSearchCtrl.addListener(() {
      setState(() {
        _requestSearchQuery = _requestSearchCtrl.text.toLowerCase();
      });
    });

    _fetchRewards();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _requestSearchCtrl.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    // Check if the tab selection has settled (not during drag/animation)
    if (!_tabController.indexIsChanging) {
      if (mounted) {
        // สั่ง rebuild FAB
        setState(() {});
      }
    }
  }

  Future<void> _loadAdminId() async {
    final prefs = await SharedPreferences.getInstance();
    _adminId = prefs.getString('empId') ?? '';
  }

  Future<void> _fetchRewards() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('${Config.apiUrl}/rewards'));
      if (response.statusCode == 200) {
        final data =
            json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        if (mounted) {
          setState(() {
            _allRewards = data;
            _applyFilters(); // กรองข้อมูลครั้งแรก
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleScanPickup() async {
    if (_adminId.isEmpty) {
      _showErrorDialog("Error", "Admin ID not found. Please relog.");
      return;
    }

    // 1. Open Scanner
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EnterpriseScannerScreen(showBottomAction: false),
      ),
    );

    if (result != null) {
      String redeemId = result.toString();

      // 2. Parse QR format: ACTION:PICKUP|ID:RDxxxxxxx
      if (redeemId.startsWith("ACTION:PICKUP|ID:")) {
        redeemId = redeemId.split("ID:")[1];
      }

      if (redeemId.startsWith("RD")) {
        _processScanRedemption(redeemId);
      } else {
        _showErrorDialog(
          "Invalid QR Code",
          "This QR code is not a valid reward ticket (Expected RDxxxx).",
        );
      }
    }
  }

  void _processScanRedemption(String redeemId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await _service.processPickupScan(_adminId, redeemId);

      if (mounted) Navigator.pop(context);

      _showSuccessDialog(
        "Pickup Confirmed! 🎉",
        "Reward: ${result['prize_name']} \nID: ${result['redeem_id']} was successfully handed out.",
      );
      _fetchRewards(); // Refresh to update list
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorDialog("Pickup Failed", e.toString());
    }
  }

  void _showSuccessDialog(String title, String msg) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(msg, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String msg) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        content: Text(msg, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // [CORE LOGIC] ฟังก์ชันกรองข้อมูล
  void _applyFilters() {
    if (_allRewards == null) return;

    setState(() {
      _filteredRewards = _allRewards!.where((r) {
        // 1. Search Logic
        final name = (r['name'] ?? '').toString().toLowerCase();
        final matchesSearch = name.contains(_searchQuery);

        // 2. Stock Filter
        final stock = r['stock'] ?? 0;
        bool matchesStock = true;
        if (_filterStockStatus == 'Low') {
          matchesStock = stock > 0 && stock < 10;
        } else if (_filterStockStatus == 'Out') {
          matchesStock = stock <= 0;
        }

        // 3. Type Filter
        final type = (r['prizeType'] ?? 'Physical').toString();
        bool matchesType = true;
        if (_filterType != 'All') {
          // เปรียบเทียบแบบ Case-insensitive เพื่อความชัวร์
          matchesType = type.toLowerCase() == _filterType.toLowerCase();
        }

        return matchesSearch && matchesStock && matchesType;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: AdminHeader(
              title: "Reward Center",
              subtitle: "Manage Rewards",
              // หน้านี้มี TabBar เลยอาจจะซ่อน Search ของ Header แล้วใช้ Search ใน Tab แทน
              searchController: null,
            ),
          ),
          // TabBar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF4A80FF),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF4A80FF),
              indicatorWeight: 3,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: "Inventory"),
                Tab(text: "Requests"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildInventoryTab(), _buildRequestsTab()],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _navigateToAddReward();
          } else {
            _handleScanPickup();
          }
        },
        backgroundColor: const Color(0xFF4A80FF),
        icon: Icon(
          _tabController.index == 0 ? Icons.add : Icons.qr_code_scanner,
          color: Colors.white,
        ),
        label: Text(
          _tabController.index == 0 ? "Add Item" : "Scan Pickup",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _navigateToAddReward() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminRewardFormScreen()),
    );
    if (result == true) _fetchRewards();
  }

  // [NEW] Requests Tab Implementation
  Widget _buildRequestsTab() {
    return FutureBuilder<List<dynamic>>(
      future: _service.getAllRedemptions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No redemption requests found."));
        }

        // --- 1. Client-Side Filtering ---
        final allRequests = snapshot.data!.where((req) {
          if (_requestSearchQuery.isEmpty) return true;

          final name = req['empName'].toString().toLowerCase();
          final prize = req['prizeName'].toString().toLowerCase();
          final id = req['redeemId'].toString().toLowerCase();

          return name.contains(_requestSearchQuery) ||
              prize.contains(_requestSearchQuery) ||
              id.contains(_requestSearchQuery);
        }).toList();

        final pendingRequests = allRequests
            .where((r) => r['status'] == 'Pending')
            .toList();
        final historyRequests = allRequests
            .where((r) => r['status'] != 'Pending')
            .toList();

        return Column(
          children: [
            // [NEW UI] Search Bar Dedicated for Requests
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _requestSearchCtrl,
                  decoration: InputDecoration(
                    hintText: "Search employee or prize...",
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    // [NEW UX] เพิ่มปุ่ม Clear
                    suffixIcon: _requestSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () => _requestSearchCtrl.clear(),
                          )
                        : null,
                  ),
                ),
              ),
            ),

            // --- 2. Request Lists ---
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                children: [
                  // Pending Section
                  if (pendingRequests.isNotEmpty) ...[
                    Text(
                      "PENDING (${pendingRequests.length})",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                        fontSize: 16,
                      ),
                    ),
                    const Divider(color: Colors.orange),
                    ...pendingRequests
                        .map((req) => _buildRequestCard(req, isPending: true))
                        .toList(),
                  ],

                  const SizedBox(height: 30),

                  // History Section
                  Text(
                    "HISTORY",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                  const Divider(color: Colors.grey),
                  if (historyRequests.isEmpty)
                    const Text("No history of approved/rejected requests."),
                  ...historyRequests
                      .map((req) => _buildRequestCard(req, isPending: false))
                      .toList(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // [NEW] Request Card Widget
  Widget _buildRequestCard(
    Map<String, dynamic> req, {
    required bool isPending,
  }) {
    final String status = req['status'];
    final String initials = req['empName'] != null
        ? req['empName'].split(' ').map((n) => n[0]).join()
        : '??';

    Color statusColor = Colors.grey;
    if (status == 'Completed')
      statusColor = Colors.green;
    else if (status == 'Cancelled')
      statusColor = Colors.red;
    else if (status == 'Pending')
      statusColor = Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            // [NEW HIERARCHY] เน้นชื่อพนักงาน
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.2),
              child: Text(
                initials,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              req['empName'] ?? 'Unknown Employee',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  req['prizeName'],
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  "${req['pointCost']} pts • ID: ${req['redeemId']}",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            isThreeLine: true,
            trailing: isPending
                ? const Icon(Icons.hourglass_empty, color: Colors.orange)
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: statusColor.withOpacity(0.1),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
          ),

          if (isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // [NEW] ปุ่ม Delete ที่ดูเหมือน Button ธรรมดา
                  OutlinedButton(
                    onPressed: () =>
                        _updateRedemptionStatus(req['redeemId'], 'Cancelled'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                    ),
                    child: const Text("Reject"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () =>
                        _updateRedemptionStatus(req['redeemId'], 'Completed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A80FF),
                    ),
                    child: const Text(
                      "Approve",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _updateRedemptionStatus(String redeemId, String status) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    // Note: The original backend updateRedemptionStatus did not take adminId,
    // so we rely on the backend checking permission via the user's login session/ID.
    final success = await _service.updateRedemptionStatus(redeemId, status);

    if (mounted) Navigator.pop(context);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Request ${status} successfully.")),
      );
      _fetchRewards(); // Refresh the tab content
    } else {
      _showErrorDialog("Error", "Failed to update status. Check API/logs.");
    }
  }

  Widget _buildInventoryTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // --- [NEW] Search & Filter Section ---
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Search Bar
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: "Search rewards...",
                    hintStyle: GoogleFonts.poppins(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. [NEW LAYOUT] Dual Dropdowns (วางคู่กัน)
              Row(
                children: [
                  // Filter A: Type
                  Expanded(
                    child: _buildModernDropdown(
                      value: _filterType,
                      items: ['All', 'Physical', 'Digital', 'Privilege'],
                      icon: Icons.category_outlined,
                      onChanged: (val) {
                        setState(() {
                          _filterType = val;
                          _applyFilters();
                        });
                      },
                      labelBuilder: (val) => val == 'All' ? 'All Types' : val,
                    ),
                  ),

                  const SizedBox(width: 12), // เว้นระยะห่าง
                  // Filter B: Stock
                  Expanded(
                    child: _buildModernDropdown(
                      value:
                          _filterStockStatus, // ใช้ตัวแปรเดิม (All, Low, Out)
                      items: ['All', 'Low', 'Out'],
                      icon: Icons.inventory_2_outlined,
                      onChanged: (val) {
                        setState(() {
                          _filterStockStatus = val;
                          _applyFilters();
                        });
                      },
                      labelBuilder: (val) {
                        if (val == 'All') return 'All Stock';
                        if (val == 'Low') return 'Low Stock';
                        if (val == 'Out') return 'Out of Stock';
                        return val;
                      },
                      // เพิ่มสีพิเศษให้ Stock เพื่อความชัดเจน
                      itemColorBuilder: (val) {
                        if (val == 'Low') return Colors.orange;
                        if (val == 'Out') return Colors.red;
                        return Colors.black87;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // --- List Data ---
        Expanded(
          child: _filteredRewards.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchRewards,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    itemCount: _filteredRewards.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final r = _filteredRewards[index];
                      return _AdminRewardCard(
                        reward: r,
                        onEdit: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminRewardFormScreen(reward: r),
                            ),
                          );
                          if (result == true) _fetchRewards();
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // [REFACTORED WIDGET] ตัวสร้าง Dropdown ที่ยืดหยุ่นขึ้น
  Widget _buildModernDropdown({
    required String value,
    required List<String> items,
    required IconData icon,
    required Function(String) onChanged,
    required String Function(String) labelBuilder,
    Color Function(String)? itemColorBuilder,
  }) {
    return Container(
      height: 44, // ความสูงมาตรฐาน
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // ปรับมุมให้เข้ากับ Search Bar
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true, // สำคัญ: ทำให้ข้อความไม่ล้น
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: Colors.grey,
          ),
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Colors.white,
          elevation: 4,
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
          items: items.map<DropdownMenuItem<String>>((String itemVal) {
            final bool isSelected = value == itemVal;
            final Color textColor = itemColorBuilder != null
                ? itemColorBuilder(itemVal)
                : (isSelected ? const Color(0xFF4A80FF) : Colors.black87);

            return DropdownMenuItem<String>(
              value: itemVal,
              child: Row(
                children: [
                  if (isSelected) ...[
                    Icon(Icons.check, size: 14, color: textColor),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    labelBuilder(itemVal),
                    style: GoogleFonts.poppins(
                      color: textColor,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          // ส่วนที่แสดงผลเมื่อพับเก็บ (Selected Item View)
          selectedItemBuilder: (context) {
            return items.map((String itemVal) {
              return Row(
                children: [
                  Icon(icon, size: 16, color: const Color(0xFF4A80FF)),
                  const SizedBox(width: 8),
                  Expanded(
                    // ป้องกัน Text ล้น
                    child: Text(
                      labelBuilder(itemVal),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            }).toList();
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? "No rewards found" : "No match found",
            style: GoogleFonts.poppins(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

// --- [CARD WIDGET: Same as previous] ---
class _AdminRewardCard extends StatelessWidget {
  final Map<String, dynamic> reward;
  final VoidCallback onEdit;

  const _AdminRewardCard({required this.reward, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final int stock = reward['stock'] ?? 0;
    final int points = reward['pointCost'] ?? 0;
    // [FIXED] Image Extraction Logic
    String coverImage = '';

    try {
      var rawImages = reward['images'];

      if (rawImages != null) {
        if (rawImages is List && rawImages.isNotEmpty) {
          coverImage = rawImages[0].toString();
        } else if (rawImages is String && rawImages.isNotEmpty) {
          // กรณี Backend ส่งมาเป็น JSON String "['url']"
          // หรือกรณีเป็น URL ตรงๆ (Legacy)
          if (rawImages.startsWith('[')) {
            List<dynamic> parsed = jsonDecode(rawImages);
            if (parsed.isNotEmpty) coverImage = parsed[0].toString();
          } else {
            coverImage = rawImages;
          }
        }
      }

      // Fallback: ถ้า images ว่าง ให้ลองดู field 'image' เดิม
      if (coverImage.isEmpty && reward['image'] != null) {
        coverImage = reward['image'].toString();
      }
    } catch (e) {
      print("Image Parse Error: $e");
    }

    Color stockColor;
    String stockLabel;
    if (stock == 0) {
      stockColor = Colors.red;
      stockLabel = "Out of Stock";
    } else if (stock < 10) {
      stockColor = Colors.orange;
      stockLabel = "Low: $stock";
    } else {
      stockColor = Colors.green;
      stockLabel = "$stock in stock";
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: coverImage.isNotEmpty
                    ? Image.network(
                        coverImage,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        cacheWidth: 200,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        loadingBuilder: (ctx, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _buildPlaceholder();
                        },
                      )
                    : _buildPlaceholder(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            (reward['prizeType'] ?? 'Item')
                                .toString()
                                .toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        const Icon(Icons.edit, size: 16, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      reward['name'] ?? 'Unknown',
                      style: GoogleFonts.kanit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6EFFF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "$points Pts",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF4A80FF),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 14,
                              color: stockColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              stockLabel,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: stockColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 90,
      height: 90,
      color: Colors.grey[200],
      child: const Icon(Icons.card_giftcard, color: Colors.grey),
    );
  }
}
