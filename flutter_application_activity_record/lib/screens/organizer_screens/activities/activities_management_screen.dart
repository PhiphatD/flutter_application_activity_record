import 'dart:convert'; // [NEW] สำหรับแปลง JSON
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart'
    as http; // [NEW] อย่าลืมเพิ่ม http ใน pubspec.yaml
import 'package:flutter_application_activity_record/theme/app_colors.dart';
import 'activity_create_screen.dart';
import 'activity_edit_screen.dart';
import 'activity_detail_screen.dart';
import '../profile/organizer_profile_screen.dart';

class ActivityManagementScreen extends StatefulWidget {
  const ActivityManagementScreen({super.key});

  @override
  State<ActivityManagementScreen> createState() =>
      _ActivityManagementScreenState();
}

class _ActivityManagementScreenState extends State<ActivityManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  // สมมติว่า logged in user คือ Organizer นี้ (ในระบบจริงต้องดึงจาก Profile/Session)
  final String _currentOrgId = 'O0001';
  int _selectedSegment = 0;
  bool _isLoading = true; // [NEW] สถานะโหลดข้อมูล

  List<Activity> _activities = [];

  @override
  void initState() {
    super.initState();
    _fetchActivities(); // [NEW] เรียกดึงข้อมูลเมื่อหน้าจอโหลด
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.trim();
      });
    });
  }

  // ฟังก์ชันดึงข้อมูลจาก API
  Future<void> _fetchActivities() async {
    // ใช้ URL ที่คุณกำหนดมา
    final String baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";
    final url = Uri.parse('$baseUrl/activities');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // แปลง response body เป็น List (ใช้ utf8.decode เพื่อรองรับภาษาไทย)
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));

        if (mounted) {
          setState(() {
            _activities = data.map((json) => Activity.fromJson(json)).toList();
            _isLoading = false;
          });
        }
      } else {
        debugPrint('Error fetching activities: ${response.statusCode}');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error connecting to API: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Activity> _filteredActivities(bool mine) {
    return _activities.where((a) {
      // 1. กรองตาม Tab (กิจกรรมของฉัน vs คนอื่น)
      final byOrg = mine ? a.orgId == _currentOrgId : a.orgId != _currentOrgId;

      // 2. ถ้าไม่มีคำค้นหา ให้คืนค่าตาม Tab เลย
      if (_searchText.isEmpty) {
        return byOrg;
      }

      // 3. ระบบค้นหาอัจฉริยะ (Smart Search)
      final searchLower = _searchText
          .toLowerCase(); // แปลงเป็นตัวเล็กเพื่อให้ค้นหาเจอแม้อักษรใหญ่/เล็กต่างกัน

      // เช็คว่าคำค้นหา ไปตรงกับส่วนใดส่วนหนึ่งของข้อมูลหรือไม่
      final matchName = a.name.toLowerCase().contains(
        searchLower,
      ); // ค้นหาจาก ชื่อกิจกรรม
      final matchLocation = a.location.toLowerCase().contains(
        searchLower,
      ); // ค้นหาจาก สถานที่
      final matchOrganizer = a.organizerName.toLowerCase().contains(
        searchLower,
      ); // ค้นหาจาก ชื่อผู้จัด
      final matchPoint = a.point.toString().contains(
        searchLower,
      ); // ค้นหาจาก คะแนน (เช่น พิมพ์ 200)
      final matchType = a.actType.toLowerCase().contains(
        searchLower,
      ); // (แถม) ค้นหาจาก ประเภทกิจกรรม (Workshop/Seminar)

      // ต้องเป็นกิจกรรมใน Tab นั้น AND ตรงกับเงื่อนไขการค้นหาอย่างน้อย 1 อย่าง
      return byOrg &&
          (matchName ||
              matchLocation ||
              matchOrganizer ||
              matchPoint ||
              matchType);
    }).toList();
  }

  void _deleteActivity(String actId) async {
    final String baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/activities/$actId'),
      );

      if (response.statusCode == 200) {
        // ลบสำเร็จ -> อัปเดตหน้าจอโดยเอาตัวนั้นออกจาก List
        setState(() {
          _activities.removeWhere((a) => a.actId == actId);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Activity deleted successfully")),
          );
        }
      } else {
        throw Exception('Failed to delete');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error deleting: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: organizerBg,
      floatingActionButton: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: FloatingActionButton(
            onPressed: () async {
              // รอผลลัพธ์เผื่อมีการสร้างกิจกรรมใหม่ จะได้รีเฟรชหน้าจอ
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateActivityScreen()),
              );
              _fetchActivities(); // รีเฟรชข้อมูลใหม่
            },
            backgroundColor: const Color(0xFF4A80FF),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomAppBar(),
            _buildSearchBar(),
            _buildViewSwitcher(),
            // [UPDATE] แสดง Loading หรือ List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildList(_selectedSegment == 0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(bool mine) {
    final items = _filteredActivities(mine);

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text(
              'No activities found',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _fetchActivities,
              child: const Text("Refresh"),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchActivities,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final a = items[index];

          return _OrganizerActivityCard(
            status: a.status,
            id: a.actId,
            type: a.actType,
            title: a.name,
            location: a.location, // [UPDATE] ใช้ข้อมูลจาก API
            organizer: a.organizerName, // [UPDATE] ใช้ข้อมูลจาก API
            points: a.point,
            currentParticipants: a.currentParticipants,
            maxParticipants: a.maxParticipants,
            isCompulsory: a.isCompulsory == 1,
            showActions: mine,
            onEdit: () async {
              // 1. ใช้ await เพื่อรอผลลัพธ์ตอนกลับมาจากหน้าแก้ไข
              final bool? result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditActivityScreen(
                    actId: a
                        .actId, // [แก้ไข] ใช้ชื่อ parameter ให้ตรงกับ constructor ของ EditActivityScreen
                  ),
                ),
              );

              // 2. ถ้ากลับมาพร้อมค่า true (แปลว่ามีการบันทึกสำเร็จ) ให้รีเฟรชข้อมูลใหม่
              if (result == true) {
                _fetchActivities();
              }
            },
            onDelete: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) {
                  return AlertDialog(
                    title: Text(
                      'Confirm Delete',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                    content: Text(
                      'Delete this activity?',
                      style: GoogleFonts.poppins(),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Cancel', style: GoogleFonts.poppins()),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          'Delete',
                          style: GoogleFonts.poppins(color: Colors.red),
                        ),
                      ),
                    ],
                  );
                },
              );
              if (ok == true) {
                _deleteActivity(a.actId);
              }
            },
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ActivityDetailScreen(
                    activityId: a.actId,
                    isOrganizerView: true,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ... (ส่วน _buildCustomAppBar, _buildSearchBar, _buildViewSwitcher คงเดิม)
  Widget _buildCustomAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: SizedBox(
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OrganizerProfileScreen(),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: const NetworkImage(
                    'https://i.pravatar.cc/150?img=32',
                  ),
                ),
              ),
            ),
            Center(
              child: Text(
                'Management',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF375987),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.black54,
                  size: 28,
                ),
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 255, 255, 255),
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search activities...',
            hintStyle: GoogleFonts.poppins(),
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 15.0,
            ),
          ),
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
            label: const Text('My Activities'),
            labelStyle: TextStyle(
              color: _selectedSegment == 0 ? Colors.black : Colors.black87,
              fontWeight: _selectedSegment == 0
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
            selected: _selectedSegment == 0,
            onSelected: (selected) {
              if (selected) setState(() => _selectedSegment = 0);
            },
            backgroundColor: Colors.white,
            selectedColor: const Color(0xFFFFD600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.0),
              side: BorderSide(
                color: _selectedSegment == 0
                    ? const Color(0xFFFFD600)
                    : Colors.grey.shade400,
              ),
            ),
            showCheckmark: false,
          ),
          const SizedBox(width: 8.0),
          ChoiceChip(
            label: const Text('Other Organizers'),
            labelStyle: TextStyle(
              color: _selectedSegment == 1 ? Colors.black : Colors.black87,
              fontWeight: _selectedSegment == 1
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
            selected: _selectedSegment == 1,
            onSelected: (selected) {
              if (selected) setState(() => _selectedSegment = 1);
            },
            backgroundColor: Colors.white,
            selectedColor: const Color(0xFFFFD600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.0),
              side: BorderSide(
                color: _selectedSegment == 1
                    ? const Color(0xFFFFD600)
                    : Colors.grey.shade400,
              ),
            ),
            showCheckmark: false,
          ),
        ],
      ),
    );
  }
}

// [NEW] Updated Activity Model ให้ตรงกับ API
class Activity {
  final String actId;
  final String orgId;
  final String organizerName; // [NEW] เพิ่มตัวแปรเก็บชื่อ
  final String actType;
  final int isCompulsory;
  final int point;
  final String name;
  final int currentParticipants;
  final int maxParticipants;
  final String status;
  final String location;

  Activity({
    required this.actId,
    required this.orgId,
    required this.organizerName, // [NEW]
    required this.actType,
    required this.isCompulsory,
    required this.point,
    required this.name,
    required this.currentParticipants,
    required this.maxParticipants,
    required this.status,
    required this.location,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      actId: json['actId']?.toString() ?? '',
      orgId: json['orgId']?.toString() ?? '',
      organizerName: json['organizerName'] ?? '-', // [NEW] รับค่าจาก JSON
      actType: json['actType'] ?? '',
      isCompulsory: json['isCompulsory'] ?? 0,
      point: json['point'] ?? 0,
      name: json['name'] ?? '',
      currentParticipants: json['currentParticipants'] ?? 0,
      maxParticipants: json['maxParticipants'] ?? 0,
      status: json['status'] ?? 'Open',
      location: json['location'] ?? '-',
    );
  }
}

// ... (Class _OrganizerActivityCard คงเดิม ไม่ต้องแก้ เพราะเรารับค่าผ่าน Constructor แล้ว)
class _OrganizerActivityCard extends StatelessWidget {
  final String status;
  final String id;
  final String type;
  final String title;
  final String location;
  final String organizer;
  final int points;
  final int currentParticipants;
  final int maxParticipants;
  final bool isCompulsory;
  final bool showActions;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _OrganizerActivityCard({
    super.key,
    required this.id,
    required this.type,
    required this.title,
    required this.location,
    required this.organizer,
    required this.points,
    required this.currentParticipants,
    required this.maxParticipants,
    required this.isCompulsory,
    required this.showActions,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    const Color cardBackgroundColor = Colors.white;
    const Color brandBlue = Color(0xFF375987);

    // [UPDATED] กำหนดสีของป้ายสถานะให้ครบทุกแบบ
    Color statusBg;
    Color statusText;
    Color statusBorder;

    if (status == 'Full' || status == 'Closed') {
      statusBg = Colors.red.shade50;
      statusText = Colors.red;
      statusBorder = Colors.red;
    } else if (status == 'Cancelled') {
      statusBg = Colors.grey.shade200;
      statusText = Colors.grey;
      statusBorder = Colors.grey;
    } else {
      // กรณี Open หรืออื่นๆ ให้เป็นสีเขียว
      statusBg = Colors.green.shade50;
      statusText = Colors.green.shade700;
      statusBorder = Colors.green.shade200;
    }

    return Stack(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16.0),
          decoration: BoxDecoration(
            color: cardBackgroundColor,
            border: Border.all(
              color: const Color.fromRGBO(0, 0, 0, 0.15),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 6.0,
                offset: const Offset(0, 3),
              ),
            ],
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            // [UPDATED] เว้นที่ด้านขวาเสมอ เพราะมีป้ายสถานะตลอดเวลา
                            padding: const EdgeInsets.only(right: 70.0),
                            child: Text(
                              title,
                              style: GoogleFonts.kanit(
                                fontWeight: FontWeight.w400,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.grey),
                    const SizedBox(height: 8.0),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _buildInfoRow(
                                text: location,
                                icon: Icons.location_on_outlined,
                              ),
                              const SizedBox(height: 8.0),
                              _buildInfoRow(
                                text: 'Organizers : $organizer',
                                icon: Icons.person_outline,
                              ),
                              const SizedBox(height: 8.0),
                              _buildInfoRow(
                                text: 'Points : $points',
                                icon: Icons.star_border_purple500_outlined,
                              ),
                            ],
                          ),
                        ),

                        if (showActions) ...[
                          const SizedBox(width: 12.0),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              InkWell(
                                onTap: onEdit,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                    horizontal: 4,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.edit,
                                        size: 18,
                                        color: Color(0xFF4A80FF),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Edit',
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF4A80FF),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16.0),
                              InkWell(
                                onTap: onDelete,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                    horizontal: 4,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Colors.redAccent,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Delete',
                                        style: GoogleFonts.poppins(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 12.0),

                    Row(
                      children: [
                        _buildTypePill(type, isCompulsory),
                        const Spacer(),
                        const Icon(
                          Icons.people_alt_outlined,
                          color: brandBlue,
                          size: 20,
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          '$currentParticipants/$maxParticipants',
                          style: GoogleFonts.kanit(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: currentParticipants >= maxParticipants
                                ? const Color(0xFFD91A1A)
                                : brandBlue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // [UPDATED] แสดงสถานะเสมอ (เอา if ออกแล้ว)
        Positioned(
          top: 12,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusBorder),
            ),
            child: Text(
              status,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: statusText,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({required String text, IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: const Color(0xFF375987), size: 22),
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

  Widget _buildTypePill(String type, bool isCompulsory) {
    final label = isCompulsory ? 'TYPE: $type • Compulsory' : 'TYPE: $type';
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
