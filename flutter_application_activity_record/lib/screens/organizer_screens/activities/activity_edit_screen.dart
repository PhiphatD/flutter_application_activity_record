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
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  Map<String, dynamic> _transformData(Map<String, dynamic> apiData) {
    List<Map<String, dynamic>> sessions = [];
    if (apiData['sessions'] != null) {
      for (var s in apiData['sessions']) {
        sessions.add({
          'SESSION_DATE': s['date'],
          'START_TIME': s['startTime'],
          'END_TIME': s['endTime'],
          'LOCATION': s['location'],
        });
      }
    }

    return {
      'ACTIVITY': {
        'ACT_NAME': apiData['name'],
        'ACT_TYPE': apiData['actType'],
        'ACT_DESCRIPTIONS': apiData['description'],
        'ACT_POINT': apiData['point'],
        'ACT_GUEST_SPEAKER': apiData['guestSpeaker'],
        'ACT_EVENT_HOST': apiData['eventHost'],
        'ACT_MAX_PARTICIPANTS': apiData['maxParticipants'],
        'DEP_ID': apiData['depName'],
        'ACT_COST': apiData['cost'],
        'ACT_TRAVEL_INFO': apiData['travelInfo'],
        'ACT_FOOD_INFO': apiData['foodInfo'],
        'ACT_MORE_DETAILS': apiData['moreDetails'],
        'ACT_PARTICIPATION_CONDITION': apiData['condition'],
        'ACT_ISCOMPULSORY': apiData['isCompulsory'],
        'ACT_STATUS': apiData['status'],
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
