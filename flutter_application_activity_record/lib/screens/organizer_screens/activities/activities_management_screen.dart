import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'activity_create_screen.dart';
import 'activity_edit_screen.dart';
import '../../employee_screens/employee_screens/activity_detail_screen.dart';
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
  final int _currentOrgId = 1;

  late List<Activity> _activities;
  late Map<int, List<ActivitySession>> _sessionsByActId;
  late Map<int, String> _organizerNameByOrgId;

  @override
  void initState() {
    super.initState();
    _activities = [
      Activity(
        actId: 1001,
        orgId: 1,
        actType: 'Seminar',
        isCompulsory: 1,
        point: 10,
        name: 'Leadership Seminar',
        currentParticipants: 18,
        maxParticipants: 30,
      ),
      Activity(
        actId: 1002,
        orgId: 1,
        actType: 'Workshop',
        isCompulsory: 0,
        point: 15,
        name: 'Agile Workshop',
        currentParticipants: 12,
        maxParticipants: 25,
      ),
      Activity(
        actId: 1003,
        orgId: 2,
        actType: 'Seminar',
        isCompulsory: 0,
        point: 8,
        name: 'Tech Trends 2025',
        currentParticipants: 20,
        maxParticipants: 40,
      ),
      Activity(
        actId: 1004,
        orgId: 3,
        actType: 'Workshop',
        isCompulsory: 1,
        point: 20,
        name: 'Security Best Practices',
        currentParticipants: 28,
        maxParticipants: 28,
      ),
    ];
    _sessionsByActId = {
      1001: [
        ActivitySession(
          actId: 1001,
          location: 'HQ Room A',
          startTime: DateTime.now().add(const Duration(days: 2, hours: 3)),
        ),
      ],
      1002: [
        ActivitySession(
          actId: 1002,
          location: 'HQ Room B',
          startTime: DateTime.now().add(const Duration(days: 5)),
        ),
      ],
      1003: [
        ActivitySession(
          actId: 1003,
          location: 'Auditorium',
          startTime: DateTime.now().add(const Duration(days: 1, hours: 1)),
        ),
      ],
      1004: [
        ActivitySession(
          actId: 1004,
          location: 'Lab 2',
          startTime: DateTime.now().add(const Duration(days: 7)),
        ),
      ],
    };
    _organizerNameByOrgId = {1: 'You', 2: 'Alice Wong', 3: 'Raj Patel'};
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Activity> _filteredActivities(bool mine) {
    return _activities.where((a) {
      final byOrg = mine ? a.orgId == _currentOrgId : a.orgId != _currentOrgId;
      final bySearch =
          _searchText.isEmpty ||
          a.name.toLowerCase().contains(_searchText.toLowerCase());
      return byOrg && bySearch;
    }).toList();
  }

  void _deleteActivity(int actId) {
    setState(() {
      _activities.removeWhere((a) => a.actId == actId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateActivityScreen()),
            );
          },
          backgroundColor: const Color(0xFF4A80FF),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildCustomAppBar(),
              _buildSearchBar(),
              Container(
                color: Colors.white,
                child: TabBar(
                  indicatorColor: const Color(0xFF4A80FF),
                  labelColor: const Color(0xFF4A80FF),
                  unselectedLabelColor: Colors.grey,
                  labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  unselectedLabelStyle: GoogleFonts.poppins(),
                  tabs: const [
                    Tab(text: 'My Activities'),
                    Tab(text: 'Other Organizers'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [_buildList(true), _buildList(false)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(bool mine) {
    final items = _filteredActivities(mine);
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No activities',
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final a = items[index];
        final sessions = _sessionsByActId[a.actId] ?? [];
        final firstSession = sessions.isNotEmpty ? sessions.first : null;
        final locationText = firstSession != null
            ? '${firstSession.location} at : ${_formatTime(firstSession.startTime)}'
            : '-';

        return _OrganizerActivityCard(
          id: a.actId.toString(),
          type: a.actType,
          title: a.name,
          location: locationText,
          organizer: _organizerNameByOrgId[a.orgId] ?? '-',
          points: a.point,
          currentParticipants: a.currentParticipants,
          maxParticipants: a.maxParticipants,
          isCompulsory: a.isCompulsory == 1,
          showActions: mine,
          onEdit: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditActivityScreen(actId: a.actId),
              ),
            );
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
                builder: (context) =>
                    ActivityDetailScreen(activityId: a.actId.toString()),
              ),
            );
          },
        );
      },
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
          Text(
            'Management',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF375987),
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

  String _formatDateTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $h:$m';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class Activity {
  final int actId;
  final int orgId;
  final String actType;
  final int isCompulsory;
  final int point;
  final String name;
  final int currentParticipants;
  final int maxParticipants;
  Activity({
    required this.actId,
    required this.orgId,
    required this.actType,
    required this.isCompulsory,
    required this.point,
    required this.name,
    required this.currentParticipants,
    required this.maxParticipants,
  });
}

class ActivitySession {
  final int actId;
  final String location;
  final DateTime startTime;
  ActivitySession({
    required this.actId,
    required this.location,
    required this.startTime,
  });
}

class _OrganizerActivityCard extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    const Color cardBackgroundColor = Colors.white;
    const Color brandBlue = Color(0xFF375987);
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.kanit(
                                  fontWeight: FontWeight.w400,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                    const Divider(color: Colors.grey),
                    const SizedBox(height: 8.0),
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
                    const SizedBox(height: 8.0),
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
                    if (showActions) ...[
                      const SizedBox(height: 12.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: onEdit,
                            icon: const Icon(
                              Icons.edit,
                              size: 18,
                              color: Color(0xFF4A80FF),
                            ),
                            label: Text(
                              'Edit',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF4A80FF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 16),
                          TextButton.icon(
                            onPressed: onDelete,
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                            label: Text(
                              'Delete',
                              style: GoogleFonts.poppins(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
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
