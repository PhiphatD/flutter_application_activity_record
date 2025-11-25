import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../models/activity_model.dart';
import '../../../widgets/custom_confirm_dialog.dart';
import '../../../widgets/auto_close_success_dialog.dart';

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
  final String baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";
  bool _isLoading = true;
  Activity? _activityData;

  String? _selectedSessionId;
  List<dynamic> _sessions = [];

  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  // --- DATA & LOGIC SECTION ---

  void _connectWebSocket() {
    try {
      final wsUrl = Uri.parse(
        'ws://numerably-nonevincive-kyong.ngrok-free.dev/ws',
      );
      _channel = WebSocketChannel.connect(wsUrl);

      _channel!.stream.listen((message) {
        if (message == "REFRESH_PARTICIPANTS" ||
            message == "REFRESH_ACTIVITIES") {
          print("⚡ Detail Update: $message");
          _fetchDetail();
        }
      }, onError: (error) => print("WS Error: $error"));
    } catch (e) {
      print("WS Connection Failed: $e");
    }
  }

  Future<void> _fetchDetail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String empId = prefs.getString('empId') ?? '';

      final response = await http.get(
        Uri.parse('$baseUrl/activities/${widget.activityId}?emp_id=$empId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final act = Activity.fromJson(data);
        if (mounted) {
          setState(() {
            _activityData = act;
            _sessions = data['sessions'] ?? [];

            // Auto-select first session if available
            if (_sessions.isNotEmpty) {
              _selectedSessionId = _sessions[0]['sessionId'];
            }

            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_activityData == null) return;
    final bool currentStatus = _activityData!.isFavorite;

    setState(() {
      _activityData!.isFavorite = !currentStatus;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String empId = prefs.getString('empId') ?? '';

      await http.post(
        Uri.parse('$baseUrl/favorites/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'emp_id': empId, 'act_id': widget.activityId}),
      );
    } catch (e) {
      print("Error toggling favorite: $e");
      setState(() {
        _activityData!.isFavorite = currentStatus;
      });
    }
  }

  Map<String, String> _getSelectedSessionDetails() {
    // Fallback to first session if none selected but sessions exist
    if (_selectedSessionId == null && _sessions.isNotEmpty) {
      _selectedSessionId = _sessions[0]['sessionId'];
    }

    if (_selectedSessionId == null) return {'date': '-', 'time': '-'};
    final session = _sessions.firstWhere(
      (s) => s['sessionId'] == _selectedSessionId,
      orElse: () => null,
    );
    if (session == null) return {'date': '-', 'time': '-'};

    try {
      final date = DateFormat(
        'd MMM y',
      ).format(DateTime.parse(session['date']));
      final time =
          "${session['startTime'].substring(0, 5)} - ${session['endTime'].substring(0, 5)}";
      return {'date': date, 'time': time};
    } catch (_) {
      return {'date': 'Invalid Date', 'time': 'Invalid Time'};
    }
  }

  Future<void> _handleRegister() async {
    // Ensure a session is selected (fallback to first one)
    if (_selectedSessionId == null && _sessions.isNotEmpty) {
      _selectedSessionId = _sessions[0]['sessionId'];
    }

    if (_selectedSessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No session available to register")),
      );
      return;
    }

    final details = _getSelectedSessionDetails();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => CustomConfirmDialog.success(
        title: "Confirm Registration",
        subtitle:
            "Join '${_activityData!.name}'?\n\n📅 ${details['date']}\n⏰ ${details['time']}",
        confirmText: "Yes, Join",
        onConfirm: () => Navigator.pop(context, true),
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final String empId = prefs.getString('empId') ?? '';

      final response = await http.post(
        Uri.parse('$baseUrl/activities/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'emp_id': empId, 'session_id': _selectedSessionId}),
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        await _fetchDetail();
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const AutoCloseSuccessDialog(
              title: "Registration Confirmed! 🎉",
              subtitle: "You have successfully joined the activity.",
              icon: Icons.check_circle,
              color: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        final err = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err['detail'] ?? "Registration Failed"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleUnregister() async {
    // Ensure a session is selected for cancellation (fallback to first one)
    if (_selectedSessionId == null && _sessions.isNotEmpty) {
      _selectedSessionId = _sessions[0]['sessionId'];
    }

    if (_selectedSessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot determine session to cancel")),
      );
      return;
    }

    final details = _getSelectedSessionDetails();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => CustomConfirmDialog.danger(
        title: "Cancel Registration?",
        subtitle:
            "You will unregister from '${_activityData!.name}'\nDate: ${details['date']} | Time: ${details['time']}",
        confirmText: "Yes, Cancel",
        onConfirm: () => Navigator.pop(context, true),
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final empId = prefs.getString('empId');

      final response = await http.post(
        Uri.parse('$baseUrl/activities/unregister'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'emp_id': empId, 'session_id': _selectedSessionId}),
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        await _fetchDetail();
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const AutoCloseSuccessDialog(
              title: "Cancellation Successful 🗑️",
              subtitle: "You are no longer registered.",
              icon: Icons.person_remove_alt_1_rounded,
              color: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['detail'] ?? "Cannot cancel"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Helper function to handle empty strings and nulls
  String _display(String? value) {
    if (value == null || value.trim().isEmpty || value == "null") return "-";
    return value;
  }

  TimeOfDay _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(":");
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return const TimeOfDay(hour: 23, minute: 59);
    }
  }

  // --- UI SECTION ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_activityData == null)
      return const Scaffold(body: Center(child: Text("Activity not found")));

    final act = _activityData!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // 1. Sliver App Bar with Image
              _buildSliverAppBar(act),

              // 2. Content Body
              SliverToBoxAdapter(
                child: Container(
                  transform: Matrix4.translationValues(0, -10, 0),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    32,
                    24,
                    120,
                  ), // Bottom padding for action bar
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header (Title, Type, Status)
                      _buildHeader(act),
                      const SizedBox(height: 24),

                      // --- REMOVED SESSION SELECTOR UI HERE ---

                      // Date & Location
                      _buildTimeLocationInfo(act),
                      const SizedBox(height: 24),

                      // Detail Grid (Always visible now)
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
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Cost & Max (Always visible)
                      Row(
                        children: [
                          Expanded(
                            child: _buildSection(
                              "Cost",
                              _display(
                                act.participationFee,
                              ), // Use _display helper
                              Icons.attach_money,
                              isHighlight: true,
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
                      // Condition (Always visible)
                      _buildSection(
                        "Condition",
                        _display(act.condition),
                        Icons.rule,
                      ),

                      // Agenda
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

                      // Description
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

                      if (act.moreDetails != '-' &&
                          act.moreDetails.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          "Note: ${act.moreDetails}",
                          style: GoogleFonts.kanit(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 3. Bottom Action Bar (Register/Cancel)
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomBar(act)),
        ],
      ),
    );
  }

  // --- WIDGET COMPONENTS ---

  Widget _buildSliverAppBar(Activity act) {
    final images = act.attachments.where((a) => a.type == 'IMAGE').toList();

    return SliverAppBar(
      expandedHeight: 280,
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
      actions: [
        // Favorite Button on AppBar
        Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.black26,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              act.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: act.isFavorite ? Colors.redAccent : Colors.white,
            ),
            onPressed: _toggleFavorite,
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: images.isNotEmpty
            ? PageView.builder(
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return Image.network(
                    images[index].url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported),
                    ),
                  );
                },
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
        text.toUpperCase(),
        style: GoogleFonts.poppins(
          color: color[700],
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // --- REMOVED: _buildSessionSelector() ---

  Widget _buildTimeLocationInfo(Activity act) {
    // Using first session date for display if multiple (as fallback)
    String dateDisplay = DateFormat('d MMM y').format(act.activityDate);
    String timeDisplay = "${act.startTime} - ${act.endTime}";

    if (_sessions.isNotEmpty) {
      final firstSession = _sessions[0];
      try {
        dateDisplay = DateFormat(
          'd MMM y',
        ).format(DateTime.parse(firstSession['date']));
        timeDisplay =
            "${firstSession['startTime'].substring(0, 5)} - ${firstSession['endTime'].substring(0, 5)}";
      } catch (_) {}
    }

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
                      dateDisplay,
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
                      timeDisplay,
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
    // MODIFIED: Always show the card. The value is already processed by _display().
    final width = (MediaQuery.of(context).size.width - 48 - 12) / 2;
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
    // MODIFIED: Always show the section.
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.kanit(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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

  Widget _buildBottomBar(Activity act) {
    // Check if activity is expired
    bool isExpired = false;
    try {
      final DateTime actDate = act.activityDate;
      final TimeOfDay endTime = _parseTime(act.endTime);
      final DateTime endDateTime = DateTime(
        actDate.year,
        actDate.month,
        actDate.day,
        endTime.hour,
        endTime.minute,
      );
      if (DateTime.now().isAfter(endDateTime)) isExpired = true;
    } catch (_) {
      if (DateTime.now().isAfter(act.activityDate.add(const Duration(days: 1))))
        isExpired = true;
    }

    // State: Expired / Completed
    if (isExpired) {
      String label = act.isRegistered ? "Activity Completed" : "Activity Ended";
      Color bgColor = act.isRegistered
          ? Colors.green.shade50
          : Colors.grey.shade100;
      Color textColor = act.isRegistered
          ? Colors.green.shade700
          : Colors.grey.shade600;
      IconData icon = act.isRegistered
          ? Icons.check_circle_outline
          : Icons.event_busy;

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: textColor),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // State: Compulsory (Mandatory)
    if (act.isCompulsory) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  "Compulsory Activity",
                  style: GoogleFonts.poppins(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // State: Registered
    if (act.isRegistered) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        "You are registered",
                        style: TextStyle(
                          color: Colors.green[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: _handleUnregister,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: const Icon(
                    Icons.person_remove_outlined,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // State: Register Now
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ElevatedButton(
          onPressed: act.status == 'Full' ? null : _handleRegister,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A80FF),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          child: Text(
            act.status == 'Full' ? "Fully Booked" : "Register Now",
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
