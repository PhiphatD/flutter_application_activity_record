import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/admin_service.dart';
import '../../../widgets/admin_header.dart';
import 'admin_employee_import_screen.dart';
import 'admin_employee_edit_screen.dart';

class AdminEmployeeListScreen extends StatefulWidget {
  const AdminEmployeeListScreen({super.key});

  @override
  State<AdminEmployeeListScreen> createState() =>
      _AdminEmployeeListScreenState();
}

class _AdminEmployeeListScreenState extends State<AdminEmployeeListScreen> {
  final AdminService _service = AdminService();
  final TextEditingController _searchController = TextEditingController();
  // [NEW] Filter Variables
  String _filterDept = "All";
  String _filterPos = "All";

  // [NEW] Master Data Lists
  List<String> _allDepartments = ["All"];
  List<String> _allPositions = ["All"];
  List<dynamic> _allEmployees = [];

  List<dynamic> _filteredEmployees = [];
  bool _isLoading = true;

  // Filter State
  String _selectedRoleFilter = "All"; // All, Admin, Organizer, Employee

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
    _fetchFilters();
    _searchController.addListener(_applyFilters);
  }

  Future<void> _fetchFilters() async {
    final depts = await _service.getDepartments();
    final positions = await _service.getPositions();
    setState(() {
      _allDepartments = ["All", ...depts];
      _allPositions = ["All", ...positions];
    });
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredEmployees = _allEmployees.where((e) {
        // 1. Search
        final name = (e['name'] ?? "").toString().toLowerCase();
        final id = (e['id'] ?? "").toString().toLowerCase();
        final matchesSearch = name.contains(query) || id.contains(query);

        // 2. Role
        bool matchesRole = true;
        if (_selectedRoleFilter != "All") {
          matchesRole =
              (e['role'] ?? "").toString().toLowerCase() ==
              _selectedRoleFilter.toLowerCase();
        }

        // 3. Department [NEW]
        bool matchesDept = true;
        if (_filterDept != "All") {
          matchesDept = (e['department'] ?? "") == _filterDept;
        }

        // 4. Position [NEW]
        bool matchesPos = true;
        if (_filterPos != "All") {
          matchesPos =
              (e['position'] ?? "") ==
              _filterPos; // ต้องแน่ใจว่า backend ส่ง field นี้มาใน /admin/employees นะครับ (ถ้ายังไม่ส่งต้องไปแก้ main.py ให้ส่ง position ด้วย)
        }

        return matchesSearch && matchesRole && matchesDept && matchesPos;
      }).toList();
    });
  }

  // [NEW] Show Filter Modal
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Filter People",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              _buildDropdownFilter("Department", _filterDept, _allDepartments, (
                val,
              ) {
                setStateModal(() => _filterDept = val!);
                setState(() => _applyFilters());
              }),

              const SizedBox(height: 16),

              _buildDropdownFilter("Position", _filterPos, _allPositions, (
                val,
              ) {
                setStateModal(() => _filterPos = val!);
                setState(() => _applyFilters());
              }),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A80FF),
                  ),
                  child: const Text(
                    "Done",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownFilter(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : "All",
              isExpanded: true,
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ให้ Content กำหนดความสูงเอง
      backgroundColor: Colors.transparent, // เพื่อให้เห็นมุมโค้งด้านบนชัดเจน
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: SafeArea(
            // [CRITICAL] ห่อด้วย SafeArea เพื่อกันชนปุ่ม Home ด้านล่าง
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Drag Handle (แถบจับด้านบน)
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 24, top: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // 2. Header
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Add Employee",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Choose how you want to add new members",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 3. Option 1: Add Manually (Card Style)
                _buildActionCard(
                  context,
                  title: "Add Manually",
                  subtitle: "Fill in details form directly",
                  icon: Icons.person_add_rounded,
                  color: const Color(0xFF4A80FF), // สีฟ้า Theme หลัก
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToAdd();
                  },
                ),

                const SizedBox(height: 16),

                // 4. Option 2: Import CSV (Card Style)
                _buildActionCard(
                  context,
                  title: "Import from CSV",
                  subtitle: "Upload bulk data via file",
                  icon: Icons.upload_file_rounded,
                  color: Colors.green, // สีเขียวสื่อถึง Excel/CSV
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToImport();
                  },
                ),

                // เว้นระยะด้านล่างเพิ่มอีกนิดให้นิ้วกดสะดวก
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToAdd() async {
    // ส่ง null ไปเพื่อให้เป็น Create Mode
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminEmployeeEditScreen(employeeData: null),
      ),
    );
    if (result == true) _fetchEmployees();
  }

  void _navigateToImport() {
    // Code เดิมของปุ่ม Import
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminEmployeeImportScreen()),
    ).then((res) {
      if (res == true) _fetchEmployees();
    });
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200), // ขอบบางๆ
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1), // พื้นหลังสีจางตาม Theme
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),

            // Texts
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),

            // Arrow Icon
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _navigateToEdit(dynamic emp) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminEmployeeEditScreen(employeeData: emp),
      ),
    );
    if (result == true) _fetchEmployees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchEmployees() async {
    setState(() => _isLoading = true);
    final data = await _service.getAllEmployees();
    if (mounted) {
      setState(() {
        _allEmployees = data;
        _applyFilters(); // กรองครั้งแรก
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteUser(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Confirm Delete"),
        content: Text(
          "Are you sure you want to remove '$name'?\nThis action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _service.deleteEmployee(id);
      if (success) {
        _fetchEmployees(); // Reload list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Deleted $name successfully"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to delete"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      // [FAB] ปุ่ม Import CSV
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(context),
        backgroundColor: const Color(0xFF4A80FF),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // 1. Unified Header
          SafeArea(
            bottom: false,
            child: AdminHeader(
              title: "Employee Management",
              subtitle: "Total People: ${_allEmployees.length}",
              searchController: _searchController,
              searchHint: "Search by name, ID, dept...",
              onFilterTap: _showFilterModal, // [NEW] Enable filter button
            ),
          ),

          // 2. Filter Chips
          Container(
            width: double.infinity,
            color: const Color(0xFFF5F7FA), // สีเดียวกับ Header
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip("All", "All"),
                  const SizedBox(width: 8),
                  _buildFilterChip("Employees", "Employee"),
                  const SizedBox(width: 8),
                  _buildFilterChip("Organizers", "Organizer"),
                  const SizedBox(width: 8),
                  _buildFilterChip("Admins", "Admin"),
                ],
              ),
            ),
          ),

          // 3. Employee List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredEmployees.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _fetchEmployees,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        100,
                      ), // Bottom padding for FAB
                      itemCount: _filteredEmployees.length,
                      itemBuilder: (context, index) {
                        return _buildEmployeeCard(_filteredEmployees[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedRoleFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) => setState(() {
        _selectedRoleFilter = value;
        _applyFilters();
      }),
      selectedColor: const Color(0xFF4A80FF),
      checkmarkColor: Colors.white,
      labelStyle: GoogleFonts.poppins(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.transparent : Colors.grey.shade300,
        ),
      ),
    );
  }

  // [UPDATED] ปรับดีไซน์ Card ให้เด้งและชัดเจนขึ้น
  Widget _buildEmployeeCard(dynamic emp) {
    // 1. Gender Logic (เหมือนเดิม)
    String gender = "male";
    final title = (emp['title'] ?? "").toString().toLowerCase();
    if (title.contains("ms") ||
        title.contains("mrs") ||
        title.contains("miss") ||
        title.contains("นาง") || // เพิ่มภาษาไทยเผื่อไว้
        title.contains("น.ส.")) {
      gender = "female";
    }

    // 2. Role Logic (เพิ่มใหม่ตาม Requirement)
    final role = (emp['role'] ?? "employee").toString().toLowerCase();
    String avatarUrl;

    if (role == 'admin') {
      // Admin -> Operator Style (ใส่หูฟัง)
      avatarUrl =
          "https://avatar.iran.liara.run/public/job/operator/$gender?username=${emp['id']}";
    } else if (role == 'organizer') {
      // Organizer -> Astronomer Style (นักดาราศาสตร์)
      avatarUrl =
          "https://avatar.iran.liara.run/public/job/astronomer/$gender?username=${emp['id']}";
    } else {
      if (gender == "male") {
        avatarUrl =
            "https://avatar.iran.liara.run/public/boy?username=${emp['id']}";
      } else {
        avatarUrl =
            "https://avatar.iran.liara.run/public/girl?username=${emp['id']}";
      }
    }

    return GestureDetector(
      onTap: () => _navigateToEdit(emp),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Avatar (ใช้ avatarUrl ที่คำนวณใหม่)
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    // [Optional] เปลี่ยนสีขอบตาม Role ด้วยก็ได้
                    color: role == 'admin'
                        ? Colors.red.shade100
                        : (role == 'organizer'
                              ? Colors.orange.shade100
                              : Colors.blue.shade100),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.grey.shade50,
                  // ใช้ CachedNetworkImageProvider เพื่อประสิทธิภาพที่ดีกว่า NetworkImage ธรรมดา
                  backgroundImage: CachedNetworkImageProvider(avatarUrl),
                ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp['name'] ?? "Unknown",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: const Color(0xFF1F2937),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildRoleBadge(emp['role']),
                        const SizedBox(width: 8),
                        Text(
                          emp['id'].toString(),
                          style: GoogleFonts.sourceCodePro(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${emp['position']} • ${emp['department']}",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Edit Icon
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                onPressed: () => _navigateToEdit(emp),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String? role) {
    Color color = Colors.blue;
    String text = "EMPLOYEE";

    if (role != null) {
      if (role.toLowerCase() == "admin") {
        color = Colors.red;
        text = "ADMIN";
      } else if (role.toLowerCase() == "organizer") {
        color = Colors.orange;
        text = "ORGANIZER";
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No employees found",
            style: GoogleFonts.poppins(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  void _launchUrl(String urlString) async {
    // ใช้ package url_launcher หรือแค่ print ไปก่อนถ้ายังไม่ได้ลง
    // canLaunchUrl(Uri.parse(urlString))...
    print("Launching: $urlString");
  }
}
