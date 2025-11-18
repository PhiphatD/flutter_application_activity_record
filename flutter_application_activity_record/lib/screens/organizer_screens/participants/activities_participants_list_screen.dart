import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application_activity_record/theme/app_colors.dart';
import 'participants_details_screen.dart';
import 'models.dart';
import '../profile/organizer_profile_screen.dart';

class ActivitiesParticipantsListScreen extends StatefulWidget {
  const ActivitiesParticipantsListScreen({super.key});

  @override
  State<ActivitiesParticipantsListScreen> createState() =>
      _ActivitiesParticipantsListScreenState();
}

class _ActivitiesParticipantsListScreenState
    extends State<ActivitiesParticipantsListScreen> {
  final int currentOrgId = 1;
  final TextEditingController _search = TextEditingController();
  String _query = '';
  bool _showJoined = false;

  final List<_Activity> _activities = [
    _Activity(
      id: 1001,
      orgId: 1,
      name: 'งานสัมมนา เทคโนโลยีรอบตัวเรา',
      type: 'Seminar',
      point: 300,
      isCompulsory: true,
      location: 'ห้องประชุม B6-310',
      startTime: const TimeOfDay(hour: 14, minute: 0),
      date: DateTime.now().subtract(const Duration(days: 10)),
      registeredCount: 2,
      joinedCount: 1,
    ),
    _Activity(
      id: 1002,
      orgId: 1,
      name: 'ฝึกอบรม กลยุทธ์การสร้างแบรนด์',
      type: 'Training',
      point: 200,
      isCompulsory: false,
      location: 'ห้องประชุม A3-403',
      startTime: const TimeOfDay(hour: 13, minute: 0),
      date: DateTime.now().add(const Duration(days: 5)),
      registeredCount: 3,
      joinedCount: 0,
    ),
    _Activity(
      id: 1003,
      orgId: 1,
      name: 'Workshop Microsoft365',
      type: 'Workshop',
      point: 500,
      isCompulsory: false,
      location: 'ห้องประชุม C9-203',
      startTime: const TimeOfDay(hour: 11, minute: 0),
      date: DateTime.now().add(const Duration(days: 30)),
      registeredCount: 5,
      joinedCount: 0,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _query = _search.text.trim()));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_Activity> get _filtered {
    final now = DateTime.now();
    bool isStarted(_Activity a) {
      final start = DateTime(
        a.date.year,
        a.date.month,
        a.date.day,
        a.startTime.hour,
        a.startTime.minute,
      );
      return !start.isAfter(now); // started or finished
    }

    return _activities
        .where((a) => a.orgId == currentOrgId)
        .where(
          (a) =>
              _query.isEmpty ||
              a.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .where((a) => _showJoined ? isStarted(a) : !isStarted(a))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: organizerBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildModeChips(),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: 10.0,
                  bottom: 16.0 + MediaQuery.of(context).padding.bottom,
                ),
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final a = _filtered[index];
                  return Padding(
                    padding: EdgeInsets.only(top: index == 0 ? 0 : 16.0),
                    child: _ActivityCard(
                      title: a.name,
                      type: a.type,
                      isCompulsory: a.isCompulsory,
                      points: a.point,
                      location: a.location,
                      timeText: '${a.startTime.format(context)}',
                      registeredCount: a.registeredCount,
                      joinedCount: a.joinedCount,
                      onTap: () {
                        final summary = ActivitySummary(
                          id: a.id,
                          name: a.name,
                          type: a.type,
                          isCompulsory: a.isCompulsory,
                          points: a.point,
                          location: a.location,
                          date: a.date,
                          startTime: a.startTime,
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ParticipantsDetailsScreen(
                              activity: summary,
                              isJoinedView: _showJoined,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildHeader() {
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
                'Participants',
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
          controller: _search,
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

  Widget _buildModeChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Registered'),
            labelStyle: TextStyle(
              color: _showJoined ? Colors.black87 : Colors.black,
              fontWeight: _showJoined ? FontWeight.normal : FontWeight.bold,
            ),
            selected: !_showJoined,
            onSelected: (s) => setState(() => _showJoined = false),
            backgroundColor: Colors.white,
            selectedColor: chipSelectedYellow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.0),
              side: BorderSide(
                color: _showJoined ? Colors.grey.shade400 : chipSelectedYellow,
              ),
            ),
            showCheckmark: false,
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Joined'),
            labelStyle: TextStyle(
              color: _showJoined ? Colors.black : Colors.black87,
              fontWeight: _showJoined ? FontWeight.bold : FontWeight.normal,
            ),
            selected: _showJoined,
            onSelected: (s) => setState(() => _showJoined = true),
            backgroundColor: Colors.white,
            selectedColor: chipSelectedYellow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.0),
              side: BorderSide(
                color: _showJoined ? chipSelectedYellow : Colors.grey.shade400,
              ),
            ),
            showCheckmark: false,
          ),
          const Spacer(),
          IconButton(onPressed: () {}, icon: const Icon(Icons.tune)),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String title;
  final String type;
  final bool isCompulsory;
  final int points;
  final String location;
  final String timeText;
  final int registeredCount;
  final int joinedCount;
  final VoidCallback onTap;

  const _ActivityCard({
    super.key,
    required this.title,
    required this.type,
    required this.isCompulsory,
    required this.points,
    required this.location,
    required this.timeText,
    required this.registeredCount,
    required this.joinedCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
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
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Text(
                    'TYPE : $type',
                    style: GoogleFonts.kanit(
                      color: Colors.black54,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isCompulsory)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10.0,
                      vertical: 4.0,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F6E7),
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Text(
                      'compulsory',
                      style: GoogleFonts.kanit(
                        color: const Color(0xFF06A710),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 6.0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6EFFF),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Text(
                    '$points Points',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF4A80FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.kanit(
                fontWeight: FontWeight.w400,
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: Color(0xFF375987),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$location at : $timeText',
                    style: GoogleFonts.kanit(fontSize: 14, color: Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.people_alt_outlined, size: 18, color: Color(0xFF375987)),
                const SizedBox(width: 6),
                Text(
                  'Registered: $registeredCount • Joined: $joinedCount',
                  style: GoogleFonts.poppins(color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Activity {
  final int id;
  final int orgId;
  final String name;
  final String type;
  final int point;
  final bool isCompulsory;
  final String location;
  final TimeOfDay startTime;
  final DateTime date;
  final int registeredCount;
  final int joinedCount;
  const _Activity({
    required this.id,
    required this.orgId,
    required this.name,
    required this.type,
    required this.point,
    required this.isCompulsory,
    required this.location,
    required this.startTime,
    required this.date,
    required this.registeredCount,
    required this.joinedCount,
  });
}
