import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/admin_service.dart';
import 'rewards/admin_point_policy_screen.dart';
import 'employees/admin_employee_import_screen.dart'; // [NEW IMPORT]
import '../../widgets/admin_header.dart';

class AdminDashboardScreen extends StatefulWidget {
  final Function(int) onSwitchTab;
  final VoidCallback onGoToRequests; // [1] เพิ่มตัวแปรนี้

  const AdminDashboardScreen({
    super.key,
    required this.onSwitchTab,
    required this.onGoToRequests, // [2] รับค่าเข้ามา
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _adminName = "Admin";

  Map<String, dynamic> _stats = {
    "totalEmployees": 0,
    "pendingRequests": 0,
    "totalRewards": 0,
    "totalActivities": 0,
  };
  bool _isLoading = true;
  final AdminService _service = AdminService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final stats = await _service.getStats();

    if (mounted) {
      setState(() {
        _adminName = prefs.getString('name') ?? "Admin";
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // [NEW] Admin Header (แบบไม่มี Search)
                      AdminHeader(
                        title: "Good Morning,",
                        subtitle: _adminName,
                        // searchController ไม่ใส่ = ไม่แสดง Search Bar
                      ),

                      // Content Section with padding
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Overview",
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // GridView Stats
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.4,
                              children: [
                                _buildStatCard(
                                  "Total Employees",
                                  "${_stats['totalEmployees']}",
                                  Icons.people,
                                  Colors.blue,
                                  onTap: () => widget.onSwitchTab(1),
                                ),
                                _buildStatCard(
                                  "Pending Requests",
                                  "${_stats['pendingRequests']}",
                                  Icons.notifications_active,
                                  Colors.orange,
                                  onTap: widget
                                      .onGoToRequests, // [3] ผูกกับฟังก์ชันนี้
                                ),
                                _buildStatCard(
                                  "Total Rewards",
                                  "${_stats['totalRewards']}",
                                  Icons.card_giftcard,
                                  Colors.purple,
                                  onTap: () => widget.onSwitchTab(2),
                                ),
                                _buildStatCard(
                                  "Activities",
                                  "${_stats['totalActivities']}",
                                  Icons.event,
                                  Colors.green,
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Activity Management coming soon!",
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),
                            Text(
                              "Quick Actions",
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildQuickActionTile(
                              icon: Icons.file_upload_outlined,
                              title: "Bulk Import Employees",
                              subtitle: "Upload CSV to add users",
                              color: Colors.green,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const AdminEmployeeImportScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            _buildQuickActionTile(
                              icon: Icons.settings_outlined,
                              title: "Point Policy",
                              subtitle: "Configure expiry date",
                              color: Colors.grey,
                              onTap: () {
                                // [MODIFIED] Navigate to Point Policy Screen
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AdminPointPolicyScreen(),
                                  ),
                                ).then((result) {
                                  if (result == true) {
                                    _loadData(); // Refresh data if policy was updated
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: Colors.grey.shade300,
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }
}
