import 'dart:convert';

class ActivityAttachment {
  final String url;
  final String type; // 'IMAGE', 'PDF', 'DOC'
  final String name;

  ActivityAttachment({
    required this.url,
    required this.type,
    required this.name,
  });

  factory ActivityAttachment.fromJson(Map<String, dynamic> json) {
    return ActivityAttachment(
      url: json['url'] ?? '',
      type: json['type'] ?? 'IMAGE',
      name: json['name'] ?? 'Attachment',
    );
  }

  Map<String, dynamic> toJson() => {'url': url, 'type': type, 'name': name};
}

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

  Map<String, dynamic> toJson() => {
    'time': time,
    'title': title,
    'detail': detail,
  };
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

  // [UPDATED] เปลี่ยนจาก String? actImage เดี่ยวๆ เป็น List
  final List<ActivityAttachment> attachments;

  bool isFavorite;
  final bool isRegistered;

  // Detail specific fields
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

  // [NEW] เพิ่ม field นี้
  final String targetCriteria;

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
    this.attachments = const [], // Default empty list
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
    // [NEW] เพิ่มตรงนี้
    this.targetCriteria = '',
  });

  // [TRICK] Getter นี้ช่วยให้โค้ดเก่า (UI การ์ด) ที่เรียก .actImage ยังทำงานได้ไม่พัง
  // โดยมันจะไปดึง URL ของรูปภาพแรกใน List มาแสดง
  String? get actImage {
    if (attachments.isEmpty) return null;
    // หาไฟล์ที่เป็น IMAGE ตัวแรก
    try {
      return attachments.firstWhere((a) => a.type == 'IMAGE').url;
    } catch (_) {
      return null; // ถ้าไม่มีรูปเลย
    }
  }

  factory Activity.fromJson(Map<String, dynamic> json) {
    DateTime date = DateTime.now();
    if (json['activityDate'] != null) {
      try {
        date = DateTime.parse(json['activityDate']);
      } catch (_) {}
    } else if (json['sessions'] != null &&
        (json['sessions'] as List).isNotEmpty) {
      try {
        date = DateTime.parse(
          json['sessions'][0]['date'] + ' ' + json['sessions'][0]['startTime'],
        );
      } catch (_) {}
    }

    String start = json['startTime'] ?? '00:00';
    String end = json['endTime'] ?? '00:00';

    if (json['sessions'] != null && (json['sessions'] as List).isNotEmpty) {
      final session = json['sessions'][0];
      start = session['startTime']?.toString() ?? '00:00';
      end = session['endTime']?.toString() ?? '00:00';
      if (start.split(':').length > 2) start = start.substring(0, 5);
      if (end.split(':').length > 2) end = end.substring(0, 5);
    }

    // [UPDATED] Parsing Logic สำหรับ Attachments
    List<ActivityAttachment> parsedAttachments = [];

    // 1. กรณี Backend ส่งมาเป็น JSON String (actAttachments)
    if (json['actAttachments'] != null && json['actAttachments'] is String) {
      try {
        final List<dynamic> list = jsonDecode(json['actAttachments']);
        parsedAttachments = list
            .map((e) => ActivityAttachment.fromJson(e))
            .toList();
      } catch (e) {
        print("Error parsing actAttachments: $e");
      }
    }
    // 2. กรณี Backend ส่งมาเป็น List โดยตรง (เผื่อไว้)
    else if (json['attachments'] != null && json['attachments'] is List) {
      parsedAttachments = (json['attachments'] as List)
          .map((e) => ActivityAttachment.fromJson(e))
          .toList();
    }
    // 3. กรณี Backend เก่าส่งมาแค่ actImage (Legacy support)
    else if (json['actImage'] != null &&
        json['actImage'].toString().isNotEmpty) {
      parsedAttachments.add(
        ActivityAttachment(
          url: json['actImage'],
          type: 'IMAGE',
          name: 'Cover Image',
        ),
      );
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

      // [UPDATED] Assign attachments
      attachments: parsedAttachments,

      isFavorite: json['isFavorite'] == true,
      isRegistered: json['isRegistered'] == true,
      guestSpeaker: json['guestSpeaker'] ?? '-',
      eventHost: json['eventHost'] ?? '-',
      organizerContact: json['organizerContact'] ?? '-',
      department: json['department'] ?? '-',
      participationFee: json['participationFee'] ?? '-',
      condition: json['condition'] ?? '-',
      foodInfo: json['foodInfo'] ?? '-',
      travelInfo: json['travelInfo'] ?? '-',
      moreDetails: json['moreDetails'] ?? '-',
      agendaList: (json['agenda'] != null && json['agenda'] is String)
          ? (jsonDecode(json['agenda']) as List)
                .map((e) => AgendaItem.fromJson(e))
                .toList()
          : (json['agendaList'] as List<dynamic>?)
                    ?.map((e) => AgendaItem.fromJson(e))
                    .toList() ??
                [],
      // [NEW] รับค่าจาก API
      targetCriteria:
          json['targetCriteria'] ?? json['ACT_TARGET_CRITERIA'] ?? '',
    );
  }
}
