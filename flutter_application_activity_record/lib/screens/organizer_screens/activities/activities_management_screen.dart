import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String _currentOrgId = '';
  List<String> _selectedTypes = [];
  String? _selectedStatus;
  List<String> _availableTypes = [];

  int _filterCompulsoryIndex = 0;
  bool _filterOnlyAvailable = false;
  int _selectedOwnerSegment = 0;
  int _selectedTimeFilter = 0;

  bool _isLoading = true;
  List<Activity> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.trim();
      });
    });
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentOrgId = prefs.getString('orgId') ?? '';
    });
    _fetchActivities(); // โหลดกิจกรรมหลังจากได้ ID แล้ว
  }

  Future<void> _fetchActivities() async {
    final String baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";
    final url = Uri.parse('$baseUrl/activities');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final loadedActivities = data
            .map((json) => Activity.fromJson(json))
            .toList();

        final types = loadedActivities.map((a) => a.actType).toSet().toList();
        if (mounted) {
          setState(() {
            _activities = data.map((json) => Activity.fromJson(json)).toList();
            _availableTypes = types;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Activity> _filteredActivities() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _activities.where((a) {
      final isMine = a.orgId == _currentOrgId;
      final ownerMatch = (_selectedOwnerSegment == 0) ? isMine : !isMine;

      final actDate = DateTime(
        a.activityDate.year,
        a.activityDate.month,
        a.activityDate.day,
      );

      bool timeMatch;
      if (_selectedTimeFilter == 0) {
        timeMatch = !actDate.isBefore(today);
      } else {
        timeMatch = actDate.isBefore(today);
      }

      if (_selectedTypes.isNotEmpty && !_selectedTypes.contains(a.actType)) {
        return false;
      }

      if (_selectedStatus != null && a.status != _selectedStatus) {
        return false;
      }

      if (_filterCompulsoryIndex == 1 && a.isCompulsory == 0) return false;
      if (_filterCompulsoryIndex == 2 && a.isCompulsory == 1) return false;

      if (_filterOnlyAvailable) {
        if (a.maxParticipants > 0 &&
            a.currentParticipants >= a.maxParticipants) {
          return false;
        }
      }

      if (_searchText.isEmpty) {
        return ownerMatch && timeMatch;
      }

      final searchLower = _searchText.toLowerCase();
      final matchName = a.name.toLowerCase().contains(searchLower);
      final matchLocation = a.location.toLowerCase().contains(searchLower);
      final matchOrg = a.organizerName.toLowerCase().contains(searchLower);

      return ownerMatch &&
          timeMatch &&
          (matchName || matchLocation || matchOrg);
    }).toList();
  }

  Map<DateTime, List<Activity>> _groupActivities(List<Activity> list) {
    if (_selectedTimeFilter == 0) {
      list.sort((a, b) => a.activityDate.compareTo(b.activityDate));
    } else {
      list.sort((a, b) => b.activityDate.compareTo(a.activityDate));
    }

    Map<DateTime, List<Activity>> groups = {};
    for (var activity in list) {
      final dateKey = DateTime(
        activity.activityDate.year,
        activity.activityDate.month,
        activity.activityDate.day,
      );
      if (groups[dateKey] == null) groups[dateKey] = [];
      groups[dateKey]!.add(activity);
    }
    return groups;
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF6CC), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.4],
        ),
      ),
    );
  }

  Widget _buildRadioOption(String label, int index, StateSetter setStateModal) {
    final isSelected = _filterCompulsoryIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setStateModal(() => _filterCompulsoryIndex = index);
          setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4A80FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1, height: 24, color: Colors.grey.shade300);
  }

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
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.all(24),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Filter Activities",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedTypes.clear();
                                _selectedStatus = null;
                                _filterCompulsoryIndex = 0;
                                _filterOnlyAvailable = false;
                              });
                              Navigator.pop(context);
                            },
                            child: Text(
                              "Reset",
                              style: GoogleFonts.poppins(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Type",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableTypes.map((type) {
                          final isSelected = _selectedTypes.contains(type);
                          return FilterChip(
                            label: Text(type),
                            selected: isSelected,
                            selectedColor: const Color(0xFFFFF6CC),
                            checkmarkColor: Colors.orange.shade900,
                            labelStyle: GoogleFonts.poppins(
                              color: isSelected
                                  ? Colors.orange.shade900
                                  : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            onSelected: (bool selected) {
                              setStateModal(() {
                                if (selected)
                                  _selectedTypes.add(type);
                                else
                                  _selectedTypes.remove(type);
                              });
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Status",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: ['Open', 'Full', 'Closed', 'Cancelled'].map((
                          status,
                        ) {
                          final isSelected = _selectedStatus == status;
                          return ChoiceChip(
                            label: Text(status),
                            selected: isSelected,
                            selectedColor: const Color(0xFFE6EFFF),
                            labelStyle: GoogleFonts.poppins(
                              color: isSelected
                                  ? const Color(0xFF375987)
                                  : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            onSelected: (bool selected) {
                              setStateModal(() {
                                _selectedStatus = selected ? status : null;
                              });
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 10),
                      Text(
                        "Requirement",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            _buildRadioOption("All", 0, setStateModal),
                            _buildVerticalDivider(),
                            _buildRadioOption("Compulsory", 1, setStateModal),
                            _buildVerticalDivider(),
                            _buildRadioOption("Optional", 2, setStateModal),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Show Available Only",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Switch(
                            value: _filterOnlyAvailable,
                            activeColor: const Color(0xFF4A80FF),
                            onChanged: (val) {
                              setStateModal(() => _filterOnlyAvailable = val);
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                      Text(
                        "Hide activities that are fully booked",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A80FF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            "Done",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _deleteActivity(String actId) async {
    final String baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/activities/$actId'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _activities.removeWhere((a) => a.actId == actId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Activity deleted successfully")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ใช้ Stack เพื่อซ้อนพื้นหลัง
      floatingActionButton: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: FloatingActionButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateActivityScreen()),
              );
              _fetchActivities();
            },
            backgroundColor: const Color(0xFF4A80FF),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(color: const Color.fromARGB(255, 255, 255, 255)),
          SafeArea(
            child: Column(
              children: [
                _buildModernHeader(),

                const SizedBox(height: 10),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildGroupedList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList() {
    final filteredList = _filteredActivities();

    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedTimeFilter == 0 ? Icons.event_available : Icons.history,
              size: 80, // ขยายใหญ่ขึ้น
              color: Colors.grey[200],
            ),
            const SizedBox(height: 16),
            Text(
              _selectedTimeFilter == 0
                  ? "You don't have any activities yet."
                  : 'No history found',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // [NEW UX] ปุ่มสร้างกิจกรรมตรงกลาง
            if (_selectedTimeFilter == 0 && _selectedOwnerSegment == 0)
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateActivityScreen(),
                    ),
                  );
                  _fetchActivities();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A80FF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                  shadowColor: const Color(0xFF4A80FF).withOpacity(0.4),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text(
                  "Create New Activity",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              )
            else
              TextButton.icon(
                onPressed: _fetchActivities,
                icon: const Icon(Icons.refresh),
                label: const Text("Refresh Data"),
              ),
          ],
        ),
      );
    }

    final groupedMap = _groupActivities(filteredList);
    final dateKeys = groupedMap.keys.toList();

    return RefreshIndicator(
      onRefresh: _fetchActivities,
      child: ListView.builder(
        padding: const EdgeInsets.only(
          left: 20.0,
          right: 20.0,
          top: 10.0,
          bottom: 80.0,
        ),
        itemCount: dateKeys.length,
        itemBuilder: (context, index) {
          final date = dateKeys[index];
          final activitiesOnDate = groupedMap[date]!;
          final isMine = _selectedOwnerSegment == 0;
          return _buildActivityGroup(date, activitiesOnDate, isMine);
        },
      ),
    );
  }

  Widget _buildActivityGroup(
    DateTime date,
    List<Activity> activities,
    bool mine,
  ) {
    final isToday = _isSameDay(date, DateTime.now());
    final bool isHistoryTab = _selectedTimeFilter == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 12.0),
          child: Row(
            children: [
              if (isToday)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "TODAY",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Text(
                _formatActivityDate(date),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isToday ? Colors.black : Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _getRelativeDateString(date),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        ...activities.map((a) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _OrganizerActivityCard(
              status: a.status,
              id: a.actId,
              type: a.actType,
              title: a.name,
              location: a.location,
              organizer: a.organizerName,
              points: a.point,
              currentParticipants: a.currentParticipants,
              maxParticipants: a.maxParticipants,
              isCompulsory: a.isCompulsory == 1,
              showActions:
                  mine &&
                  _selectedTimeFilter ==
                      0, // แก้ไขได้เฉพาะของฉัน และเป็น Active
              startTime: a.startTime,
              endTime: a.endTime,
              isHistory: isHistoryTab,
              onEdit: () async {
                final bool? result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditActivityScreen(actId: a.actId),
                  ),
                );
                if (result == true) _fetchActivities();
              },
              onDelete: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
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
                  ),
                );
                if (ok == true) _deleteActivity(a.actId);
              },
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ActivityDetailScreen(
                      activityId: a.actId,
                      isOrganizerView: true,

                      // [FIX] ส่งสิทธิ์การแก้ไขเข้าไป
                      // แก้ได้เฉพาะเมื่อ: เป็นของฉัน (mine) AND อยู่ในแท็บ Active (_selectedTimeFilter == 0)
                      canEdit: mine && _selectedTimeFilter == 0,
                    ),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ],
    );
  }

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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OrganizerProfileScreen(),
                  ),
                ),
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
    final hasFilter =
        _selectedTypes.isNotEmpty ||
        _selectedStatus != null ||
        _filterCompulsoryIndex != 0 ||
        _filterOnlyAvailable;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
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
                  hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 15.0,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _showFilterModal,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasFilter ? const Color(0xFF4A80FF) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10.0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.filter_list_rounded,
                color: hasFilter ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerSegment() {
    // [FIX] เพิ่ม Align ครอบเพื่อให้ชิดซ้าย
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            ChoiceChip(
              avatar: Icon(
                Icons.person_outline,
                size: 18,
                color: _selectedOwnerSegment == 0 ? Colors.black : Colors.grey,
              ),
              label: const Text('My Activities'),
              labelStyle: TextStyle(
                color: _selectedOwnerSegment == 0
                    ? Colors.black
                    : Colors.black87,
                fontWeight: _selectedOwnerSegment == 0
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
              selected: _selectedOwnerSegment == 0,
              onSelected: (selected) {
                if (selected) setState(() => _selectedOwnerSegment = 0);
              },
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFFFFD600),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.0),
                side: BorderSide(
                  color: _selectedOwnerSegment == 0
                      ? const Color(0xFFFFD600)
                      : Colors.grey.shade400,
                ),
              ),
              showCheckmark: false,
            ),
            const SizedBox(width: 8.0),
            ChoiceChip(
              avatar: Icon(
                Icons.group_outlined,
                size: 18,
                color: _selectedOwnerSegment == 1 ? Colors.black : Colors.grey,
              ),
              label: const Text('Other Organizers'),
              labelStyle: TextStyle(
                color: _selectedOwnerSegment == 1
                    ? Colors.black
                    : Colors.black87,
                fontWeight: _selectedOwnerSegment == 1
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
              selected: _selectedOwnerSegment == 1,
              onSelected: (selected) {
                if (selected) setState(() => _selectedOwnerSegment = 1);
              },
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFFFFD600),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.0),
                side: BorderSide(
                  color: _selectedOwnerSegment == 1
                      ? const Color(0xFFFFD600)
                      : Colors.grey.shade400,
                ),
              ),
              showCheckmark: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Row 1: Profile & Greeting
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OrganizerProfileScreen(),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF4A80FF),
                      width: 2,
                    ),
                  ),
                  child: const CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(
                      'https://i.pravatar.cc/150?img=32',
                    ), // หรือใช้รูปจริง
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome back,",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  Text(
                    "Organizer Team", // หรือใส่ชื่อจริง _currentOrganizerName
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF375987),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.black54,
                ),
                onPressed: () {},
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Row 2: Search Bar & Filter
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search activities...',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey[400],
                        size: 22,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _showFilterModal,
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A80FF), // สีปุ่ม Filter เด่นๆ
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.tune, color: Colors.white),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Row 3: Smart Tabs (รวม My/Other และ Active/History)
          // เราจะใช้ดีไซน์แบบ "Chips" แนวนอนที่เลื่อนได้ เพื่อประหยัดที่
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Group 1: Owner (My / Others)
                _buildChipSelector(
                  "My Activities",
                  _selectedOwnerSegment == 0,
                  () => setState(() => _selectedOwnerSegment = 0),
                ),
                const SizedBox(width: 8),
                _buildChipSelector(
                  "Others",
                  _selectedOwnerSegment == 1,
                  () => setState(() => _selectedOwnerSegment = 1),
                ),

                Container(
                  height: 24,
                  width: 1,
                  color: Colors.grey.shade300,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ), // เส้นคั่น
                // Group 2: Status (Active / History)
                _buildChipSelector(
                  "Active",
                  _selectedTimeFilter == 0,
                  () => setState(() => _selectedTimeFilter = 0),
                  isStatus: true,
                ),
                const SizedBox(width: 8),
                _buildChipSelector(
                  "History",
                  _selectedTimeFilter == 1,
                  () => setState(() => _selectedTimeFilter = 1),
                  isStatus: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget สำหรับปุ่มเลือกเล็กๆ (Chip)
  Widget _buildChipSelector(
    String label,
    bool isSelected,
    VoidCallback onTap, {
    bool isStatus = false,
  }) {
    // สี Active: ถ้าเป็นกลุ่ม Owner ใช้สีเหลือง, ถ้าเป็น Status ใช้สีฟ้า
    final activeColor = isStatus
        ? const Color(0xFFE6EFFF)
        : const Color(0xFFFFF8E1);
    final activeText = isStatus
        ? const Color(0xFF4A80FF)
        : Colors.amber.shade900;
    final border = isStatus ? const Color(0xFF4A80FF) : Colors.amber;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? border.withOpacity(0.3) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? activeText : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            _buildTimeFilterTab("Active", 0),
            _buildTimeFilterTab("History", 1),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeFilterTab(String text, int index) {
    final isSelected = _selectedTimeFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTimeFilter = index),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? Colors.black : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  String _formatActivityDate(DateTime eventDate) {
    final formatter = DateFormat('d MMMM y', 'en_US');
    return formatter.format(eventDate);
  }

  String _getRelativeDateString(DateTime eventDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cleanEventDate = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
    );
    final differenceInDays = cleanEventDate.difference(today).inDays;

    if (differenceInDays < 0) return "Past Event";
    if (differenceInDays == 0) return "Today";
    if (differenceInDays == 1) return "Tomorrow";
    if (differenceInDays <= 7) return "This Week";
    return "";
  }
}

// Activity Model
class Activity {
  final String actId;
  final String orgId;
  final String actType;
  final int isCompulsory;
  final int point;
  final String name;
  final int currentParticipants;
  final int maxParticipants;
  final String status;
  final String location;
  final String organizerName;
  final DateTime activityDate;
  final String startTime;
  final String endTime;

  Activity({
    required this.actId,
    required this.orgId,
    required this.actType,
    required this.isCompulsory,
    required this.point,
    required this.name,
    required this.currentParticipants,
    required this.maxParticipants,
    required this.status,
    required this.location,
    required this.organizerName,
    required this.activityDate,
    required this.startTime,
    required this.endTime,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    DateTime date = DateTime.now();
    if (json['activityDate'] != null) {
      date = DateTime.parse(json['activityDate']);
    }
    return Activity(
      actId: json['actId']?.toString() ?? '',
      orgId: json['orgId']?.toString() ?? '',
      actType: json['actType'] ?? '',
      isCompulsory: json['isCompulsory'] ?? 0,
      point: json['point'] ?? 0,
      name: json['name'] ?? '',
      currentParticipants: json['currentParticipants'] ?? 0,
      maxParticipants: json['maxParticipants'] ?? 0,
      status: json['status'] ?? 'Open',
      location: json['location'] ?? '-',
      organizerName: json['organizerName'] ?? '-',
      activityDate: date,
      startTime: json['startTime'] ?? '-',
      endTime: json['endTime'] ?? '-',
    );
  }
}

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
  final String startTime;
  final String endTime;
  final bool isHistory; // ตัวแปรสำคัญ

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
    this.startTime = "-",
    this.endTime = "-",
    this.isHistory = false,
  });

  Color _getTypeColor(String type) {
    // ถ้าเป็น History ให้คืนค่าสีเทาเสมอ เพื่อสื่อว่าเป็นอดีต
    if (isHistory) return Colors.grey.shade400;

    switch (type.toLowerCase()) {
      case 'training':
        return const Color(0xFF4A80FF);
      case 'seminar':
        return const Color(0xFFFF9F1C);
      case 'workshop':
        return const Color(0xFF2EC4B6);
      case 'expo':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor(type);
    final bool isFull =
        maxParticipants > 0 && currentParticipants >= maxParticipants;

    // [UX Improvement] ทำให้การ์ด History ดูจางลงเล็กน้อย
    final displayOpacity = isHistory ? 0.7 : 1.0;

    // --- Status Logic ---
    Color statusBg;
    Color statusTextCol;
    String displayStatus;

    if (isHistory) {
      // ถ้าเป็น History บังคับโชว์ "Ended" สีเทา
      displayStatus = "Ended";
      statusBg = Colors.grey.shade200;
      statusTextCol = Colors.grey.shade600;
    } else {
      // ถ้าเป็น Active โชว์ตามจริง
      displayStatus = status;
      switch (status) {
        case 'Full':
          statusBg = Colors.red.shade50;
          statusTextCol = Colors.red;
          break;
        case 'Closed':
          statusBg = Colors.grey.shade100;
          statusTextCol = Colors.grey.shade700;
          break;
        default: // Open
          statusBg = const Color(0xFFE6EFFF);
          statusTextCol = const Color(0xFF4A80FF);
      }
    }

    return Opacity(
      opacity: displayOpacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white, // ยังคงพื้นหลังขาวเพื่อให้ clean
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                isHistory ? 0.02 : 0.05,
              ), // เงาจางลงถ้าเป็น History
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Side Bar (Grey if history)
                  Container(
                    width: 6,
                    color: typeColor, // ใช้สีที่คำนวณไว้ (เทา หรือ สีตามประเภท)
                  ),

                  // 2. Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- Tags Row ---
                          Row(
                            children: [
                              // Type Tag
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  type.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Status Tag (Ended or Open)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  displayStatus,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: statusTextCol,
                                  ),
                                ),
                              ),

                              const Spacer(),
                              // [Hidden Menu for History]
                              if (showActions && !isHistory)
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    icon: Icon(
                                      Icons.more_horiz,
                                      color: Colors.grey.shade400,
                                    ),
                                    onSelected: (v) {
                                      if (v == 'edit') onEdit();
                                      if (v == 'delete') onDelete();
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (isHistory)
                                // แสดงไอคอน Lock แทนเมนู เพื่อบอกว่าแก้ไขไม่ได้
                                Icon(
                                  Icons.lock_outline,
                                  size: 14,
                                  color: Colors.grey.shade300,
                                ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // --- Title ---
                          Text(
                            title,
                            style: GoogleFonts.kanit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              // ถ้าเป็น History สีชื่อจะดรอปลงนิดนึง
                              color: isHistory
                                  ? Colors.grey.shade700
                                  : const Color(0xFF1F2937),
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 6),

                          // --- Time & Location ---
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                startTime != "-" ? startTime : "TBA",
                                style: GoogleFonts.kanit(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  location,
                                  style: GoogleFonts.kanit(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // --- Progress & Stats ---
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.group_outlined,
                                          size: 16,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          // History: เน้นยอดสรุป, Active: เน้นเป้า
                                          isHistory
                                              ? "Total: $currentParticipants"
                                              : "$currentParticipants/$maxParticipants",
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    // Progress Bar
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value: maxParticipants > 0
                                            ? currentParticipants /
                                                  maxParticipants
                                            : 0,
                                        backgroundColor: Colors.grey.shade100,
                                        // History: Progress Bar สีเทา
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              isHistory
                                                  ? Colors.grey.shade400
                                                  : (isFull
                                                        ? Colors.red
                                                        : typeColor),
                                            ),
                                        minHeight: 3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Points Badge (Grey if history)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isHistory
                                      ? Colors.grey.shade100
                                      : Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isHistory
                                        ? Colors.transparent
                                        : Colors.amber.shade100,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: isHistory
                                          ? Colors.grey.shade400
                                          : Colors.amber.shade800,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "$points",
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isHistory
                                            ? Colors.grey.shade500
                                            : Colors.amber.shade900,
                                      ),
                                    ),
                                  ],
                                ),
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
          ),
        ),
      ),
    );
  }
}
