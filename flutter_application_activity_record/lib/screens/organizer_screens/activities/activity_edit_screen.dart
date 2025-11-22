import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'activity_create_screen.dart';

class EditActivityScreen extends StatefulWidget {
  final String actId;
  const EditActivityScreen({super.key, required this.actId});

  @override
  State<EditActivityScreen> createState() => _EditActivityScreenState();
}

class _EditActivityScreenState extends State<EditActivityScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _initialData;
  final String baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final url = Uri.parse('$baseUrl/activities/${widget.actId}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final formattedData = _transformData(data);

        if (mounted) {
          setState(() {
            _initialData = formattedData;
            _isLoading = false;
          });
        }
      } else {
        print("Failed to load activity for edit: ${response.body}");
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      print("Edit Fetch Error: $e");
      if (mounted) Navigator.pop(context);
    }
  }

  // Mapping ข้อมูลจาก Backend (CamelCase) -> Frontend Form Keys (UPPER_CASE)
  Map<String, dynamic> _transformData(Map<String, dynamic> apiData) {
    List<Map<String, dynamic>> sessions = [];
    if (apiData['sessions'] != null) {
      for (var s in apiData['sessions']) {
        sessions.add({
          'SESSION_DATE': s['date'], // Backend: date
          'START_TIME': s['startTime'], // Backend: startTime
          'END_TIME': s['endTime'], // Backend: endTime
          'LOCATION': s['location'], // Backend: location
        });
      }
    }

    return {
      'ACTIVITY': {
        'ACT_NAME': apiData['name'],
        'ACT_TYPE': apiData['actType'],
        'ACT_DESCRIPTIONS': apiData['description'],
        'ACT_POINT': apiData['point'],
        'ACT_MAX_PARTICIPANTS': apiData['maxParticipants'],
        'ACT_STATUS': apiData['status'],
        'ACT_ISCOMPULSORY': apiData['isCompulsory'],
        'ACT_IMAGE': apiData['actImage'], // Cover Image
        'ACT_COST': apiData['cost'],

        // Mapping More Details
        'DEP_ID': apiData['depName'], // Backend ส่งชื่อแผนกมาใน field depName
        'ACT_EVENT_HOST': apiData['eventHost'],
        'ACT_GUEST_SPEAKER': apiData['guestSpeaker'],
        'ACT_FOOD_INFO': apiData['foodInfo'],
        'ACT_TRAVEL_INFO': apiData['travelInfo'],
        'ACT_MORE_DETAILS': apiData['moreDetails'],
        'ACT_PARTICIPATION_CONDITION':
            apiData['condition'], // Backend: condition -> Frontend: ACT_PARTICIPATION_CONDITION
        // Complex Objects (ส่ง Raw ไปให้ CreateScreen แกะเอง)
        'ACT_AGENDA': apiData['agenda'],
        'ACT_TARGET_CRITERIA': apiData['targetCriteria'],
      },
      'ORGANIZER': {
        'ORG_NAME': apiData['organizerName'],
        'ORG_CONTACT_INFO': apiData['organizerContact'],
      },
      'SESSIONS': sessions,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return CreateActivityScreen(
      initialData: _initialData,
      isEdit: true,
      actId: widget.actId,
    );
  }
}
