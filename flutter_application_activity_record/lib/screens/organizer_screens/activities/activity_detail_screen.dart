import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/activity_model.dart';
import 'activity_edit_screen.dart';

class ActivityDetailScreen extends StatefulWidget {
  final String activityId;
  final bool isOrganizerView;
  final bool canEdit;
  const ActivityDetailScreen({
    Key? key,
    required this.activityId,
    this.isOrganizerView = true,
    this.canEdit = false,
  }) : super(key: key);

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  final String baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";
  Activity? _activityData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchActivityDetails();
  }

  Future<void> _fetchActivityDetails() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String empId = prefs.getString('empId') ?? '';

      final url = Uri.parse(
        '$baseUrl/activities/${widget.activityId}?emp_id=$empId',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final activity = Activity.fromJson(data);
        if (mounted) {
          setState(() {
            _activityData = activity;
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

  void _navigateToEdit() async {
    if (_activityData == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditActivityScreen(actId: widget.activityId),
      ),
    );
    _fetchActivityDetails();
  }

  // Helper function to handle empty strings
  String _display(String? value) {
    if (value == null || value.trim().isEmpty || value == "null") return "-";
    return value;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_activityData == null)
      return const Scaffold(body: Center(child: Text("Activity not found.")));

    final act = _activityData!;
    bool isPastEvent =
        act.status == 'Closed' ||
        act.status == 'Completed' ||
        act.status == 'Cancelled' ||
        DateTime.now().isAfter(act.activityDate.add(const Duration(days: 1)));

    bool showEditButton = widget.canEdit && !isPastEvent;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),

      // ซ่อน/แสดง ปุ่มตาม Logic ใหม่
      floatingActionButton: showEditButton
          ? FloatingActionButton.extended(
              onPressed: _navigateToEdit,
              backgroundColor: const Color(0xFF4A80FF),
              icon: const Icon(Icons.edit, color: Colors.white),
              label: Text(
                "Edit Activity",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            )
          : null, // ถ้าไม่มีสิทธิ์ หรือจบแล้ว ให้เป็น null (ซ่อนปุ่ม)
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(act),
          SliverToBoxAdapter(
            child: Container(
              // [UI TWEAK] ปรับให้โค้งมนและดันขึ้นมาน้อยลง เพื่อให้เห็นรูปชัดขึ้น
              transform: Matrix4.translationValues(0, -10, 0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(
                24,
                32,
                24,
                100,
              ), // เพิ่ม Padding บน-ล่าง
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header & Status
                  _buildHeader(act),
                  const SizedBox(height: 24),

                  // 2. Target Audience (Full Detail)
                  _buildTargetAudienceInfo(act),
                  const SizedBox(height: 24),

                  // 3. Date & Location
                  _buildTimeLocationInfo(act),
                  const SizedBox(height: 24),

                  // 4. Organizer & Host Details (Grid)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildInfoCard(
                        Icons.person,
                        "Speaker",
                        _display(act.guestSpeaker),
                      ),
                      _buildInfoCard(
                        Icons.business,
                        "Host",
                        _display(act.eventHost),
                      ),
                      _buildInfoCard(
                        Icons.restaurant,
                        "Food",
                        _display(act.foodInfo),
                      ),
                      _buildInfoCard(
                        Icons.directions_bus,
                        "Travel",
                        _display(act.travelInfo),
                      ),
                      _buildInfoCard(
                        Icons.support_agent,
                        "Contact",
                        _display(act.organizerContact),
                      ),
                      _buildInfoCard(
                        Icons.domain,
                        "Dept",
                        _display(act.department),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 5. Cost & Condition
                  Row(
                    children: [
                      Expanded(
                        child: _buildSection(
                          "Cost",
                          act.participationFee == '-'
                              ? '-'
                              : act.participationFee,
                          Icons.attach_money,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSection(
                          "Max People",
                          "${act.maxParticipants}",
                          Icons.group,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    "Condition",
                    _display(act.condition),
                    Icons.rule,
                  ),

                  // 6. Agenda
                  const SizedBox(height: 24),
                  Text(
                    "Agenda",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (act.agendaList.isNotEmpty)
                    _buildAgendaTimeline(act.agendaList)
                  else
                    Text(
                      "- No Agenda Provided -",
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),

                  // 7. Description & More Details
                  const SizedBox(height: 24),
                  Text(
                    "Description",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _display(act.description),
                    style: GoogleFonts.kanit(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    "More Details",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _display(act.moreDetails),
                    style: GoogleFonts.kanit(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(Activity act) {
    return SliverAppBar(
      expandedHeight: 280, // [UI TWEAK] เพิ่มความสูงให้เห็นรูปมากขึ้น
      pinned: true,
      backgroundColor: const Color(0xFF4A80FF),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Colors.black26,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: act.actImage != null && act.actImage!.isNotEmpty
            ? Image.network(
                act.actImage!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[300],
                  child: const Icon(
                    Icons.broken_image,
                    size: 50,
                    color: Colors.grey,
                  ),
                ),
              )
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4A80FF), Color(0xFF2D5BFF)],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.image, size: 80, color: Colors.white54),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(Activity act) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildTag(act.actType, Colors.blue),
            const SizedBox(width: 8),
            _buildTag(
              act.status,
              act.status == 'Open' ? Colors.green : Colors.red,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber[100]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                  Text(
                    " ${act.point} Pts",
                    style: GoogleFonts.poppins(
                      color: Colors.amber[900],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          act.name,
          style: GoogleFonts.kanit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "${act.currentParticipants} / ${act.maxParticipants} Registered",
          style: GoogleFonts.inter(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: color[700],
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTargetAudienceInfo(Activity act) {
    // Logic แกะ JSON
    String displayType = "Everyone";
    List<String> depts = [];
    List<String> positions = [];

    if (act.targetCriteria.isNotEmpty) {
      try {
        final Map<String, dynamic> data = jsonDecode(act.targetCriteria);
        final type = data['type'];
        if (type == 'specific') {
          displayType = "Specific Group";
          depts = List<String>.from(data['departments'] ?? []);
          positions = List<String>.from(data['positions'] ?? []);
        }
      } catch (e) {
        print("Error parsing target criteria: $e");
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups, size: 20, color: Colors.black54),
              const SizedBox(width: 8),
              Text(
                "Target Audience",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Type Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: displayType == "Everyone"
                  ? Colors.green[50]
                  : Colors.orange[50],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              displayType,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: displayType == "Everyone"
                    ? Colors.green[700]
                    : Colors.orange[800],
              ),
            ),
          ),

          // Show Details if specific
          if (depts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "Departments:",
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: depts
                  .map(
                    (d) => Chip(
                      label: Text(d, style: const TextStyle(fontSize: 10)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  )
                  .toList(),
            ),
          ],

          if (positions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "Positions:",
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: positions
                  .map(
                    (p) => Chip(
                      label: Text(p, style: const TextStyle(fontSize: 10)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeLocationInfo(Activity act) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('d MMM y').format(act.activityDate),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      "${act.startTime} - ${act.endTime}",
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey[300]),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.place, size: 16, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    act.location,
                    style: GoogleFonts.kanit(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    final width =
        (MediaQuery.of(context).size.width - 48 - 12) / 2; // 2 columns
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.kanit(fontSize: 13, fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    String label,
    String value,
    IconData icon, {
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlight ? const Color(0xFFF0FDF4) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlight ? Colors.green.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isHighlight ? Colors.green[700] : Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: GoogleFonts.kanit(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaTimeline(List<AgendaItem> agendaList) {
    return Column(
      children: agendaList.asMap().entries.map((entry) {
        final isLast = entry.key == agendaList.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  entry.value.time,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4A80FF),
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(width: 2, color: Colors.grey[200]),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.value.title,
                        style: GoogleFonts.kanit(fontWeight: FontWeight.w600),
                      ),
                      if (entry.value.detail.isNotEmpty)
                        Text(
                          entry.value.detail,
                          style: GoogleFonts.kanit(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
