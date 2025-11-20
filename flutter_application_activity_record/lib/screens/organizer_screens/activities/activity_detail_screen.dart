import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class ActivityDetail {
  final String id;
  final String type;
  final String title;
  final String location;
  final String organizer;
  final int points;
  final DateTime activityDate;
  final String timeRange;
  final String status;
  final String guestSpeaker;
  final String eventHost;
  final String organizerContact;
  final String department;
  final String participationFee;
  final String description;
  final bool isRegistered;
  final String condition;
  final String foodInfo;
  final String travelInfo;
  final String moreDetails;

  ActivityDetail({
    required this.id,
    required this.type,
    required this.title,
    required this.location,
    required this.organizer,
    required this.points,
    required this.activityDate,
    required this.timeRange,
    required this.status,
    required this.guestSpeaker,
    required this.eventHost,
    required this.organizerContact,
    required this.department,
    required this.participationFee,
    required this.description,
    required this.isRegistered,
    required this.condition,
    required this.foodInfo,
    required this.travelInfo,
    required this.moreDetails,
  });

  factory ActivityDetail.fromJson(Map<String, dynamic> json) {
    String loc = "-";
    DateTime date = DateTime.now();
    String tRange = "-";

    if (json['sessions'] != null && (json['sessions'] as List).isNotEmpty) {
      final firstSession = json['sessions'][0];
      final dateStr = firstSession['date'];
      final startTimeStr = firstSession['startTime'].toString();
      final endTimeStr = firstSession['endTime'].toString();

      final startParts = startTimeStr.split(':');
      final endParts = endTimeStr.split(':');

      final formattedStart = "${startParts[0]}:${startParts[1]}";
      final formattedEnd = "${endParts[0]}:${endParts[1]}";

      loc = firstSession['location'];
      date = DateTime.parse("$dateStr $startTimeStr");
      tRange = "$formattedStart - $formattedEnd";
    }

    final cost = json['cost'];
    String fee = (cost == 0 || cost == 0.0) ? 'Free' : '$cost THB';

    return ActivityDetail(
      id: json['actId']?.toString() ?? '',
      type: json['actType'] ?? '',
      title: json['name'] ?? '',
      location: loc,
      organizer: json['organizerName'] ?? '-',
      points: json['point'] ?? 0,
      activityDate: date,
      timeRange: tRange,
      status: json['status'] ?? 'Open',
      guestSpeaker: json['guestSpeaker'] ?? '-',
      eventHost: json['eventHost'] ?? '-',
      organizerContact: json['organizerContact'] ?? '-',
      department: json['depName'] ?? '-',
      participationFee: fee,
      description: json['description'] ?? '-',
      isRegistered: false,
      condition: json['condition'] ?? '-',
      foodInfo: json['foodInfo'] ?? '-',
      travelInfo: json['travelInfo'] ?? '-',
      moreDetails: json['moreDetails'] ?? '-',
    );
  }
}

class ActivityDetailScreen extends StatefulWidget {
  final String activityId;
  final bool isOrganizerView;
  const ActivityDetailScreen({
    Key? key,
    required this.activityId,
    this.isOrganizerView = false,
  }) : super(key: key);

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  ActivityDetail? _activityData;
  bool _isLoading = true;
  final String baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";

  @override
  void initState() {
    super.initState();
    _fetchActivityDetails();
  }

  Future<void> _fetchActivityDetails() async {
    setState(() => _isLoading = true);
    final url = Uri.parse('$baseUrl/activities/${widget.activityId}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final activity = ActivityDetail.fromJson(data);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'Activity Detail',
        style: GoogleFonts.kanit(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_activityData == null) {
      return const Center(child: Text("Error: Activity not found."));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildTimeInfo(),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          _buildDetailItem(
            Icons.person_outline,
            'Guest Speaker',
            _activityData!.guestSpeaker,
          ),
          _buildDetailItem(
            Icons.business_outlined,
            'Event Host',
            _activityData!.eventHost,
          ),
          _buildDetailItem(
            Icons.support_agent_outlined,
            'Organizer',
            _activityData!.organizer,
          ),
          _buildDetailItem(
            Icons.email_outlined,
            'Organizer Contact',
            _activityData!.organizerContact,
          ),
          _buildDetailItem(
            Icons.apartment_outlined,
            'Department',
            _activityData!.department,
          ),
          _buildDetailItem(
            Icons.confirmation_number_outlined,
            'Participation Fee',
            _activityData!.participationFee,
          ),
          _buildDetailItem(
            Icons.restaurant_menu,
            'Food',
            _activityData!.foodInfo,
          ),
          _buildDetailItem(
            Icons.directions_bus,
            'Travel',
            _activityData!.travelInfo,
          ),
          _buildDetailItem(Icons.rule, 'Condition', _activityData!.condition),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'About this activity',
            style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _activityData!.description,
            style: GoogleFonts.kanit(
              fontSize: 15,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          if (_activityData!.moreDetails != '-' &&
              _activityData!.moreDetails.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'More Details:',
                  style: GoogleFonts.kanit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _activityData!.moreDetails,
                  style: GoogleFonts.kanit(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    Color statusColorBg = Colors.green.shade50;
    Color statusColorText = Colors.green.shade800;
    if (_activityData!.status == 'Full' || _activityData!.status == 'Closed') {
      statusColorBg = Colors.red.shade50;
      statusColorText = Colors.red;
    } else if (_activityData!.status == 'Cancelled') {
      statusColorBg = Colors.grey.shade200;
      statusColorText = Colors.grey;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // [UPDATED] ใช้ Expanded เพื่อให้ชื่อกิจกรรมขึ้นบรรทัดใหม่ได้
            Expanded(
              child: Text(
                _activityData!.title,
                style: GoogleFonts.kanit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 6.0,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFE6EFFF),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                '${_activityData!.points} Points',
                style: GoogleFonts.kanit(
                  color: const Color(0xFF4A80FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
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
                'TYPE: ${_activityData!.type}',
                style: GoogleFonts.kanit(
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10.0,
                vertical: 4.0,
              ),
              decoration: BoxDecoration(
                color: statusColorBg,
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(color: statusColorBg),
              ),
              child: Text(
                _activityData!.status,
                style: GoogleFonts.kanit(
                  color: statusColorText,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              color: Color(0xFF4A80FF),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _activityData!.location,
                style: GoogleFonts.kanit(fontSize: 15, color: Colors.black87),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeInfo() {
    String formattedDate = DateFormat(
      'd MMMM yyyy',
    ).format(_activityData!.activityDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  color: Colors.grey[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                // [UPDATED] Flexible
                Flexible(
                  child: Text(
                    formattedDate,
                    style: GoogleFonts.kanit(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.access_time_outlined,
                  color: Colors.grey[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _activityData!.timeRange,
                    style: GoogleFonts.kanit(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
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

  Widget _buildDetailItem(IconData icon, String title, String value) {
    if (value == '-' || value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey[600], size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.kanit(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.kanit(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
