import 'package:flutter/material.dart';
import 'activity_create_screen.dart';

class EditActivityScreen extends StatelessWidget {
  final int actId;
  const EditActivityScreen({super.key, required this.actId});

  Map<String, dynamic> _loadMock(int id) {
    final base = {
      1001: {
        'ACTIVITY': {
          'ACT_NAME': 'Leadership Seminar',
          'ACT_TYPE': 'Seminar',
          'ACT_DESCRIPTIONS': 'สัมมนาแนวทางภาวะผู้นำ',
          'ACT_POINT': 10,
          'ACT_GUEST_SPEAKER': 'Mr. John Doe',
          'ACT_EVENT_HOST': 'Leadership Institute',
          'ACT_MAX_PARTICIPANTS': 30,
          'DEP_ID': 'All Departments',
          'ACT_COST': 0.0,
          'ACT_TRAVEL_INFO': '',
          'ACT_FOOD_INFO': '',
          'ACT_MORE_DETAILS': '',
          'ACT_PARTICIPATION_CONDITION': '',
          'ACT_ISCOMPULSORY': 1,
        },
        'ORGANIZER': {
          'ORG_NAME': 'You',
          'ORG_CONTACT_INFO': 'organizer@example.com',
        },
        'SESSIONS': [
          {
            'SESSION_DATE': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
            'START_TIME': '14:00',
            'END_TIME': '16:00',
            'LOCATION': 'HQ Room A',
          },
        ],
      },
      1002: {
        'ACTIVITY': {
          'ACT_NAME': 'Agile Workshop',
          'ACT_TYPE': 'Workshop',
          'ACT_DESCRIPTIONS': 'เวิร์กชอป Agile และ Scrum',
          'ACT_POINT': 15,
          'ACT_GUEST_SPEAKER': 'Agile Coach Team',
          'ACT_EVENT_HOST': 'Agile Guild',
          'ACT_MAX_PARTICIPANTS': 25,
          'DEP_ID': 'All Departments',
          'ACT_COST': 0.0,
          'ACT_TRAVEL_INFO': '',
          'ACT_FOOD_INFO': '',
          'ACT_MORE_DETAILS': '',
          'ACT_PARTICIPATION_CONDITION': '',
          'ACT_ISCOMPULSORY': 0,
        },
        'ORGANIZER': {
          'ORG_NAME': 'You',
          'ORG_CONTACT_INFO': 'organizer@example.com',
        },
        'SESSIONS': [
          {
            'SESSION_DATE': DateTime.now().add(const Duration(days: 5)).toIso8601String(),
            'START_TIME': '09:00',
            'END_TIME': '12:00',
            'LOCATION': 'HQ Room B',
          },
        ],
      },
      1003: {
        'ACTIVITY': {
          'ACT_NAME': 'Tech Trends 2025',
          'ACT_TYPE': 'Seminar',
          'ACT_DESCRIPTIONS': 'แนวโน้มเทคโนโลยีปี 2025',
          'ACT_POINT': 8,
          'ACT_GUEST_SPEAKER': 'Industry Experts',
          'ACT_EVENT_HOST': 'Tech Assoc.',
          'ACT_MAX_PARTICIPANTS': 40,
          'DEP_ID': 'All Departments',
          'ACT_COST': 0.0,
          'ACT_TRAVEL_INFO': '',
          'ACT_FOOD_INFO': '',
          'ACT_MORE_DETAILS': '',
          'ACT_PARTICIPATION_CONDITION': '',
          'ACT_ISCOMPULSORY': 0,
        },
        'ORGANIZER': {
          'ORG_NAME': 'Alice Wong',
          'ORG_CONTACT_INFO': 'alice@example.com',
        },
        'SESSIONS': [
          {
            'SESSION_DATE': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
            'START_TIME': '13:00',
            'END_TIME': '15:00',
            'LOCATION': 'Auditorium',
          },
        ],
      },
      1004: {
        'ACTIVITY': {
          'ACT_NAME': 'Security Best Practices',
          'ACT_TYPE': 'Workshop',
          'ACT_DESCRIPTIONS': 'แนวทางความปลอดภัยไซเบอร์',
          'ACT_POINT': 20,
          'ACT_GUEST_SPEAKER': 'CyberSec Team',
          'ACT_EVENT_HOST': 'CyberSec Lab',
          'ACT_MAX_PARTICIPANTS': 28,
          'DEP_ID': 'All Departments',
          'ACT_COST': 0.0,
          'ACT_TRAVEL_INFO': '',
          'ACT_FOOD_INFO': '',
          'ACT_MORE_DETAILS': '',
          'ACT_PARTICIPATION_CONDITION': '',
          'ACT_ISCOMPULSORY': 1,
        },
        'ORGANIZER': {
          'ORG_NAME': 'Raj Patel',
          'ORG_CONTACT_INFO': 'raj@example.com',
        },
        'SESSIONS': [
          {
            'SESSION_DATE': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
            'START_TIME': '10:00',
            'END_TIME': '12:00',
            'LOCATION': 'Lab 2',
          },
        ],
      },
    };
    return base[id] ?? base[1001]!;
  }

  @override
  Widget build(BuildContext context) {
    final initial = _loadMock(actId);
    return CreateActivityScreen(initialData: initial, isEdit: true);
  }
}
