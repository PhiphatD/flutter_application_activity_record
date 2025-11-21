class AgendaItem {
  final String time;
  final String title;
  final String detail;

  AgendaItem({required this.time, required this.title, required this.detail});

  factory AgendaItem.fromJson(Map<String, dynamic> json) {
    return AgendaItem(
      time: json['time'] ?? '-',
      title: json['title'] ?? '-',
      detail: json['detail'] ?? '',
    );
  }
}

class Activity {
  final String actId;
  final String actType;
  final String name;
  final String location;
  final String organizerName;
  final int point;
  final int currentParticipants;
  final int maxParticipants;
  final bool isCompulsory;
  final String status;
  final DateTime activityDate;
  final String startTime;
  final String endTime;
  final String sessionId;
  final String description;
  final String? actImage;
  final bool isFavorite;
  final bool isRegistered;

  // Detail specific fields (nullable or default empty)
  final String guestSpeaker;
  final String eventHost;
  final String organizerContact;
  final String department;
  final String participationFee;
  final String condition;
  final String foodInfo;
  final String travelInfo;
  final String moreDetails;
  final List<AgendaItem> agendaList;

  Activity({
    required this.actId,
    required this.actType,
    required this.name,
    required this.location,
    this.organizerName = '-',
    this.point = 0,
    this.currentParticipants = 0,
    this.maxParticipants = 0,
    this.isCompulsory = false,
    this.status = 'Upcoming',
    required this.activityDate,
    this.startTime = '00:00',
    this.endTime = '00:00',
    this.sessionId = '',
    this.description = '',
    this.actImage,
    this.isFavorite = false,
    this.isRegistered = false,
    this.guestSpeaker = '-',
    this.eventHost = '-',
    this.organizerContact = '-',
    this.department = '-',
    this.participationFee = '-',
    this.condition = '-',
    this.foodInfo = '-',
    this.travelInfo = '-',
    this.moreDetails = '-',
    this.agendaList = const [],
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    DateTime date = DateTime.now();
    if (json['activityDate'] != null) {
      try {
        date = DateTime.parse(json['activityDate']);
      } catch (_) {}
    } else if (json['sessions'] != null &&
        (json['sessions'] as List).isNotEmpty) {
      // Fallback for Detail API which might nest date in sessions
      try {
        date = DateTime.parse(
          json['sessions'][0]['date'] + ' ' + json['sessions'][0]['startTime'],
        );
      } catch (_) {}
    }

    // Handle time range if present (Detail API)
    String start = json['startTime'] ?? '00:00';
    String end = json['endTime'] ?? '00:00';

    if (json['sessions'] != null && (json['sessions'] as List).isNotEmpty) {
      final session = json['sessions'][0];
      start = session['startTime']?.toString() ?? '00:00';
      end = session['endTime']?.toString() ?? '00:00';

      // Clean up seconds if present (e.g. 09:00:00 -> 09:00)
      if (start.split(':').length > 2) {
        start = start.substring(0, 5);
      }
      if (end.split(':').length > 2) {
        end = end.substring(0, 5);
      }
    }

    return Activity(
      actId: json['actId']?.toString() ?? json['id']?.toString() ?? '',
      actType: json['actType'] ?? json['type'] ?? 'Activity',
      name: json['name'] ?? json['title'] ?? 'Unknown Activity',
      location:
          json['location'] ??
          (json['sessions'] != null && (json['sessions'] as List).isNotEmpty
              ? json['sessions'][0]['location']
              : '-'),
      organizerName: json['organizerName'] ?? json['organizer'] ?? '-',
      point: json['point'] ?? json['points'] ?? 0,
      currentParticipants: json['currentParticipants'] ?? 0,
      maxParticipants: json['maxParticipants'] ?? 0,
      isCompulsory: json['isCompulsory'] == 1 || json['isCompulsory'] == true,
      status: json['status'] ?? 'Upcoming',
      activityDate: date,
      startTime: start,
      endTime: end,
      sessionId:
          json['sessionId'] ??
          (json['sessions'] != null && (json['sessions'] as List).isNotEmpty
              ? json['sessions'][0]['sessionId']
              : ''),
      description: json['description'] ?? '',
      actImage: json['actImage'],
      isFavorite: json['isFavorite'] == true,
      isRegistered: json['isRegistered'] == true,

      // Detail fields
      guestSpeaker: json['guestSpeaker'] ?? '-',
      eventHost: json['eventHost'] ?? '-',
      organizerContact: json['organizerContact'] ?? '-',
      department: json['department'] ?? '-',
      participationFee: json['participationFee'] ?? '-',
      condition: json['condition'] ?? '-',
      foodInfo: json['foodInfo'] ?? '-',
      travelInfo: json['travelInfo'] ?? '-',
      moreDetails: json['moreDetails'] ?? '-',
      agendaList:
          (json['agendaList'] as List<dynamic>?)
              ?.map((e) => AgendaItem.fromJson(e))
              .toList() ??
          [],
    );
  }
}
