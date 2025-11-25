import 'dart:convert';
import 'dart:io';
import 'dart:async'; // For Timer
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart'; // [CHANGED] ใช้ ImagePicker แทน FilePicker เพื่อความง่ายในการจัดการรูป
import 'package:day_night_time_picker/day_night_time_picker.dart';
import 'package:day_night_time_picker/lib/state/time.dart';
import '../../../models/activity_model.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';

class CreateActivityScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final bool isEdit;
  final String? actId;

  const CreateActivityScreen({
    super.key,
    this.initialData,
    this.isEdit = false,
    this.actId,
  });

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  final String baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";
  bool _isSubmitting = false;
  bool _isLoadingData = true;
  Set<DateTime> _busyDates = {};
  // --- Controllers ---
  final _formKey = GlobalKey<FormState>();

  // 1. Basic Info
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController(); // Description (Long text)

  // 2. Date & Location
  final _locationCtrl = TextEditingController();
  TimeOfDay? _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay? _endTime = const TimeOfDay(hour: 12, minute: 0);
  DateTime? _selectedDate = DateTime.now().add(const Duration(days: 7));

  // 3. Host & Organizer Info (DB: ACT_EVENT_HOST, ACT_GUEST_SPEAKER)
  final _organizerNameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _hostCtrl = TextEditingController(); // ACT_EVENT_HOST
  final _guestCtrl = TextEditingController(); // ACT_GUEST_SPEAKER
  String? _selectedHostDept;
  final _customHostDeptCtrl = TextEditingController();

  // 4. Quota & Points
  final _pointsCtrl = TextEditingController();
  final _maxParticipantsCtrl = TextEditingController();
  final _feeCtrl = TextEditingController(); // ACT_COST

  // 5. More Details (DB: ACT_FOOD_INFO, ACT_TRAVEL_INFO, etc.)
  final _foodCtrl = TextEditingController();
  final _travelCtrl = TextEditingController();
  final _moreCtrl = TextEditingController();
  final _conditionCtrl = TextEditingController(); // ACT_PARTICIPATION_CONDITION

  // 6. Attachments & Cover
  // 6. Attachments & Cover
  // final _imageUrlCtrl = TextEditingController(); // [REMOVED]
  final ImagePicker _picker = ImagePicker();
  List<ActivityAttachment> _existingAttachments = []; // รูปเดิม (URL)
  List<File> _newImages = []; // รูปใหม่ (File)
  // List<PlatformFile> _selectedFiles = []; // [REMOVED]

  // --- State Variables ---
  String? _selectedType = 'Training';
  final List<String> _activityTypes = [
    'Training',
    'Seminar',
    'Workshop',
    'Activity',
    'Expo',
    'Other',
  ];
  final _customTypeCtrl = TextEditingController();

  String? _selectedStatus = 'Open';
  final List<String> _statuses = ['Open', 'Full', 'Closed', 'Cancelled'];

  int _isCompulsory = 0;

  // Target Audience (DB: ACT_TARGET_CRITERIA)
  String _targetType = 'all'; // all, specific
  List<String> _selectedTargetDepts = [];
  List<String> _selectedTargetPositions = [];

  // Agenda (DB: ACT_AGENDA)
  List<Map<String, String>> _agendaItems = [];

  // Dropdown Data (Mock or fetched)
  List<String> _dbDepartments = [];
  List<String> _dbPositions = [];

  // [NEW] Auto Count Logic
  int _autoCountedParticipants = 0;
  bool _isCounting = false;
  Timer? _debounce;

  Future<void> _fetchTargetCount() async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isCounting = true);

      try {
        final prefs = await SharedPreferences.getInstance();
        final adminId = prefs.getString('empId');

        final body = {
          "type": _targetType,
          "departments": _selectedTargetDepts,
          "positions": _selectedTargetPositions,
          "admin_id": adminId,
        };

        final response = await http.post(
          Uri.parse('$baseUrl/activities/count-target'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (mounted) {
            setState(() {
              _autoCountedParticipants = data['count'];
              // Update controller if compulsory so it submits correctly
              if (_isCompulsory == 1) {
                _maxParticipantsCtrl.text = _autoCountedParticipants.toString();
              }
            });
          }
        }
      } catch (e) {
        print("Count Error: $e");
      } finally {
        if (mounted) setState(() => _isCounting = false);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _fetchBusyDates();
  }

  Future<void> _fetchBusyDates() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/activities'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final Set<DateTime> dates = {};

        for (var item in data) {
          if (item['activityDate'] != null) {
            final d = DateTime.parse(item['activityDate']);
            // เก็บเฉพาะวันที่ (ตัดเวลาทิ้ง) เพื่อเปรียบเทียบง่าย
            dates.add(DateUtils.dateOnly(d));
          }
        }

        if (mounted) {
          setState(() {
            _busyDates = dates;
          });
        }
      }
    } catch (e) {
      print("Error fetching busy dates: $e");
    }
  }

  Future<void> _fetchInitialData() async {
    try {
      // Fetch Departments & Positions
      final depRes = await http.get(Uri.parse('$baseUrl/departments'));
      final posRes = await http.get(Uri.parse('$baseUrl/positions'));

      if (mounted) {
        setState(() {
          if (depRes.statusCode == 200) {
            final List data = jsonDecode(utf8.decode(depRes.bodyBytes));
            _dbDepartments = data
                .map<String>((e) => e['name'].toString())
                .toList();
            _dbDepartments.add('Other');
          }
          if (posRes.statusCode == 200) {
            final List data = jsonDecode(utf8.decode(posRes.bodyBytes));
            _dbPositions = data.map<String>((e) => e.toString()).toList();
          }
        });
      }

      // Load User Info
      final prefs = await SharedPreferences.getInstance();
      if (!widget.isEdit) {
        _organizerNameCtrl.text = prefs.getString('name') ?? 'Organizer';
      }

      // Load Edit Data
      if (widget.initialData != null) {
        _loadExistingData();
      }
    } catch (e) {
      print("Error fetching initial data: $e");
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  void _openSmartCalendar() async {
    // [FIX 1] ปรับความกว้างให้ยืดหยุ่นขึ้น (ขั้นต่ำ 300px เพื่อให้หัวข้อไม่เบียด)
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.9).clamp(300.0, 400.0);

    final values = await showCalendarDatePicker2Dialog(
      context: context,
      config: CalendarDatePicker2WithActionButtonsConfig(
        calendarType: CalendarDatePicker2Type.single,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),

        // Design Settings
        selectedDayHighlightColor: const Color(0xFF4A80FF),

        // Weekday Labels
        weekdayLabels: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
        weekdayLabelTextStyle: GoogleFonts.inter(
          color: Colors.grey,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),

        // [FIX 2] ลดขนาด Font หัวข้อ (เดือน ปี) ลงเหลือ 14 หรือ 15
        controlsTextStyle: GoogleFonts.kanit(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          fontSize: 14, // ลดจาก 16 เป็น 14 เพื่อแก้ Overflow
        ),

        // Custom Builder (คงเดิม)
        dayBuilder:
            ({
              required date,
              textStyle,
              decoration,
              isSelected,
              isDisabled,
              isToday,
            }) {
              // ... (Logic วาดจุดสีส้ม เหมือนเดิมเป๊ะ) ...
              final bool hasActivity = _busyDates.contains(
                DateUtils.dateOnly(date),
              );
              Color textColor = Colors.black87;
              if (isSelected == true)
                textColor = Colors.white;
              else if (isDisabled == true)
                textColor = Colors.grey.shade300;
              else if (isToday == true)
                textColor = const Color(0xFF4A80FF);

              return Container(
                decoration: decoration,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      date.day.toString(),
                      style: GoogleFonts.inter(
                        color: textColor,
                        fontWeight: (isSelected == true || isToday == true)
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                    if (hasActivity && isDisabled != true) ...[
                      const SizedBox(height: 4),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: (isSelected == true)
                              ? Colors.white
                              : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
      ),
      // ใช้ความกว้างใหม่
      dialogSize: Size(dialogWidth, 400),
      borderRadius: BorderRadius.circular(20),
      value: [_selectedDate],
    );

    if (values != null && values.isNotEmpty && values[0] != null) {
      setState(() {
        _selectedDate = values[0];
      });
    }
  }

  void _loadExistingData() {
    final act = widget.initialData!['ACTIVITY'];
    final org = widget.initialData!['ORGANIZER'];
    final sessions = widget.initialData!['SESSIONS'] as List?;

    if (act != null) {
      _nameCtrl.text = act['ACT_NAME'] ?? '';
      _descCtrl.text = act['ACT_DESCRIPTIONS'] ?? '';
      _pointsCtrl.text = (act['ACT_POINT'] ?? 0).toString();
      _maxParticipantsCtrl.text = (act['ACT_MAX_PARTICIPANTS'] ?? 0).toString();

      String type = act['ACT_TYPE'] ?? 'Training';
      if (_activityTypes.contains(type)) {
        _selectedType = type;
      } else {
        _selectedType = 'Other';
        _customTypeCtrl.text = type;
      }

      _selectedStatus = act['ACT_STATUS'] ?? 'Open';
      _isCompulsory = (act['ACT_ISCOMPULSORY'] ?? 0) == 1 ? 1 : 0;

      // Load Full DB Fields
      // _imageUrlCtrl.text = act['ACT_IMAGE'] ?? ''; // [REMOVED]
      _feeCtrl.text = (act['ACT_COST'] ?? 0).toString();
      _hostCtrl.text = act['ACT_EVENT_HOST'] ?? '';
      _guestCtrl.text = act['ACT_GUEST_SPEAKER'] ?? '';
      _foodCtrl.text = act['ACT_FOOD_INFO'] ?? '';
      _travelCtrl.text = act['ACT_TRAVEL_INFO'] ?? '';
      _moreCtrl.text = act['ACT_MORE_DETAILS'] ?? '';
      _conditionCtrl.text = act['ACT_PARTICIPATION_CONDITION'] ?? '';

      // Load Department
      String depName = act['DEP_ID'] ?? '';
      if (_dbDepartments.contains(depName)) {
        _selectedHostDept = depName;
      } else {
        _selectedHostDept = 'Other';
        _customHostDeptCtrl.text = depName;
      }

      // Load Agenda
      if (act['ACT_AGENDA'] != null && act['ACT_AGENDA'].isNotEmpty) {
        try {
          final List<dynamic> agendaJson = jsonDecode(act['ACT_AGENDA']);
          _agendaItems = agendaJson
              .map((e) => Map<String, String>.from(e))
              .toList();
        } catch (_) {}
      }

      // Load Target Criteria
      if (act['ACT_TARGET_CRITERIA'] != null) {
        try {
          final criteria = jsonDecode(act['ACT_TARGET_CRITERIA']);
          _targetType = criteria['type'] ?? 'all';
          if (_targetType == 'specific') {
            _selectedTargetDepts = List<String>.from(
              criteria['departments'] ?? [],
            );
            _selectedTargetPositions = List<String>.from(
              criteria['positions'] ?? [],
            );
          }
        } catch (_) {}
      }
      // [NEW] Load Attachments
      if (act['ACT_ATTACHMENTS'] != null) {
        // กรณี Frontend ส่งมาเป็น List<ActivityAttachment> แล้ว
        if (act['ACT_ATTACHMENTS'] is List) {
          _existingAttachments = List<ActivityAttachment>.from(
            act['ACT_ATTACHMENTS'].map((x) => ActivityAttachment.fromJson(x)),
          );
        } else if (act['ACT_ATTACHMENTS'] is String) {
          try {
            final List<dynamic> list = jsonDecode(act['ACT_ATTACHMENTS']);
            _existingAttachments = list
                .map((x) => ActivityAttachment.fromJson(x))
                .toList();
          } catch (_) {}
        }
      }
      // Fallback for legacy 'ACT_IMAGE'
      else if (act['ACT_IMAGE'] != null &&
          act['ACT_IMAGE'].toString().isNotEmpty) {
        _existingAttachments.add(
          ActivityAttachment(
            url: act['ACT_IMAGE'],
            type: 'IMAGE',
            name: 'Cover',
          ),
        );
      }
    }

    if (org != null) {
      _organizerNameCtrl.text = org['ORG_NAME'] ?? '';
      _contactCtrl.text = org['ORG_CONTACT_INFO'] ?? '';
    }

    if (sessions != null && sessions.isNotEmpty) {
      final first = sessions.first;
      _locationCtrl.text = first['LOCATION'] ?? '';
      if (first['SESSION_DATE'] != null)
        _selectedDate = DateTime.parse(first['SESSION_DATE']);
      if (first['START_TIME'] != null)
        _startTime = _parseTime(first['START_TIME']);
      if (first['END_TIME'] != null) _endTime = _parseTime(first['END_TIME']);
    }
  }

  TimeOfDay? _parseTime(String s) {
    try {
      final parts = s.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  // --- Image Logic ---
  Future<void> _pickImages() async {
    int currentCount = _existingAttachments.length + _newImages.length;
    if (currentCount >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maximum 10 images allowed.")),
      );
      return;
    }

    final List<XFile> picked = await _picker.pickMultiImage(
      limit: 10 - currentCount,
      imageQuality: 80, // บีบอัดรูปเล็กน้อย
    );

    if (picked.isNotEmpty) {
      setState(() {
        _newImages.addAll(picked.map((e) => File(e.path)));
      });
    }
  }

  // Upload Helper
  Future<String?> _uploadFile(File file) async {
    try {
      final uploadUrl = Uri.parse('$baseUrl/upload/image');
      final request = http.MultipartRequest('POST', uploadUrl);
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(respStr);
        return "$baseUrl${data['url']}"; // Return Full URL
      }
    } catch (e) {
      print("Upload error: $e");
    }
    return null;
  }

  // --- Submit Logic ---
  Future<void> _submitData() async {
    // ถ้าเป็น Compulsory ให้ใส่ค่ามั่วๆ ไปก่อน (เช่น 0) เพราะ Backend จะคำนวณทับให้อยู่ดี
    if (_isCompulsory == 1) {
      _maxParticipantsCtrl.text = "0";
    }

    if (!_formKey.currentState!.validate()) return;
    if (_locationCtrl.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter location")));
      return;
    }

    // [VALIDATION] Check Images
    if (_existingAttachments.isEmpty && _newImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least 1 cover image.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // 1. Upload New Images
    List<Map<String, String>> finalAttachments = [];

    // Add existing
    for (var att in _existingAttachments) {
      finalAttachments.add({
        'url': att.url,
        'type': att.type,
        'name': att.name,
      });
    }

    // Upload and add new
    for (var file in _newImages) {
      String? url = await _uploadFile(file);
      if (url != null) {
        finalAttachments.add({
          'url': url,
          'type': 'IMAGE',
          'name': file.path.split('/').last,
        });
      }
    }

    // Prepare Data
    final startStr =
        '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}';
    final sessionDate = _selectedDate ?? DateTime.now();

    final finalType = _selectedType == 'Other'
        ? _customTypeCtrl.text
        : _selectedType;
    final finalHostDept = _selectedHostDept == 'Other'
        ? _customHostDeptCtrl.text
        : _selectedHostDept;

    final targetCriteria = {
      "type": _targetType,
      "departments": _targetType == 'specific' ? _selectedTargetDepts : [],
      "positions": _targetType == 'specific' ? _selectedTargetPositions : [],
    };

    final body = {
      "ACTIVITY": {
        "ACT_NAME": _nameCtrl.text,
        "ACT_TYPE": finalType,
        "ACT_DESCRIPTIONS": _descCtrl.text,
        "ACT_POINT": int.tryParse(_pointsCtrl.text) ?? 0,
        "ACT_MAX_PARTICIPANTS": int.tryParse(_maxParticipantsCtrl.text) ?? 0,
        "DEP_ID": finalHostDept ?? 'General',
        "ACT_STATUS": _selectedStatus,
        "ACT_ISCOMPULSORY": _isCompulsory,

        // [NEW] ส่งเป็น List Attachments
        "ACT_ATTACHMENTS": finalAttachments,

        "ACT_AGENDA": jsonEncode(_agendaItems),
        "ACT_COST": double.tryParse(_feeCtrl.text) ?? 0.0,
        "ACT_EVENT_HOST": _hostCtrl.text,
        "ACT_GUEST_SPEAKER": _guestCtrl.text,
        "ACT_FOOD_INFO": _foodCtrl.text,
        "ACT_TRAVEL_INFO": _travelCtrl.text,
        "ACT_MORE_DETAILS": _moreCtrl.text,
        "ACT_PARTICIPATION_CONDITION": _conditionCtrl.text,
        "ACT_TARGET_CRITERIA": jsonEncode(targetCriteria),
      },
      "ORGANIZER": {
        "ORG_NAME": _organizerNameCtrl.text,
        "ORG_CONTACT_INFO": _contactCtrl.text,
      },
      "SESSIONS": [
        {
          "SESSION_DATE": sessionDate.toIso8601String(),
          "START_TIME": startStr,
          "END_TIME": endStr,
          "LOCATION": _locationCtrl.text,
        },
      ],
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      final empId = prefs.getString('empId') ?? '';

      http.Response response;
      if (widget.isEdit && widget.actId != null) {
        response = await http.put(
          Uri.parse('$baseUrl/activities/${widget.actId}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
      } else {
        response = await http.post(
          Uri.parse('$baseUrl/activities?emp_id=$empId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.isEdit ? "Updated!" : "Created!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception("Failed: ${response.body}");
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(
          widget.isEdit ? 'Edit Activity' : 'Create Activity',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.black),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitData,
            child: Text(
              "Publish",
              style: GoogleFonts.inter(
                color: const Color(0xFF4A80FF),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 1. Images
            _buildCard(child: _buildImageSection()), // [NEW]
            const SizedBox(height: 24),

            // 2. Basic Info
            _buildSectionTitle("Basic Info"),
            _buildBasicInfoCard(),
            const SizedBox(height: 24),

            // 3. Date & Location
            _buildSectionTitle("Time & Location"),
            _buildDateTimeLocationCard(),
            const SizedBox(height: 24),

            // 4. Agenda
            _buildSectionTitle("Agenda / Timeline"),
            _buildAgendaCard(),
            const SizedBox(height: 24),

            // 5. Target Audience
            _buildSectionTitle("Target Audience"),
            _buildTargetAudienceCard(),
            const SizedBox(height: 24),

            // 6. More Details (DB Fields)
            _buildSectionTitle("More Details"),
            _buildMoreDetailsCard(),
            const SizedBox(height: 24),

            // 7. Attachments (Multiple Files) -> Moved to top as Gallery
            // _buildSectionTitle("Documents & Files"),
            // _buildAttachmentsCard(),
            // const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- Widgets ---

  // [NEW UI] ส่วนจัดการรูปภาพแบบ Grid
  Widget _buildImageSection() {
    int totalCount = _existingAttachments.length + _newImages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Gallery ($totalCount/10)",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            TextButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text("Add Photos"),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (totalCount == 0)
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade300,
                style: BorderStyle.solid,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    "No images added",
                    style: GoogleFonts.inter(color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: totalCount,
            itemBuilder: (context, index) {
              // Logic: Show Existing First, Then New
              bool isExisting = index < _existingAttachments.length;
              ImageProvider imgProvider;

              if (isExisting) {
                imgProvider = NetworkImage(_existingAttachments[index].url);
              } else {
                imgProvider = FileImage(
                  _newImages[index - _existingAttachments.length],
                );
              }

              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: imgProvider,
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isExisting) {
                            _existingAttachments.removeAt(index);
                          } else {
                            _newImages.removeAt(
                              index - _existingAttachments.length,
                            );
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (!isExisting)
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "NEW",
                          style: TextStyle(color: Colors.white, fontSize: 8),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  // [STYLE] กำหนดสไตล์กลางสำหรับ Dropdown เพื่อให้แก้ที่เดียวเปลี่ยนทั้งหน้า
  CustomDropdownDecoration _getDropdownDecoration() {
    return CustomDropdownDecoration(
      closedBorder: Border.all(color: Colors.grey.shade300),
      closedFillColor: const Color(0xFFF9FAFB), // สีพื้นหลังเทาอ่อน
      closedBorderRadius: BorderRadius.circular(12),
      hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
      headerStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
      expandedFillColor: Colors.white,
      expandedBorder: Border.all(color: Colors.grey.shade200),
      expandedBorderRadius: BorderRadius.circular(12),
    );
  }

  Widget _buildBasicInfoCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: _nameCtrl,
            label: "Activity Name *",
            validator: (v) => v!.isEmpty ? "Required" : null,
          ),
          const SizedBox(height: 16),

          // [UPDATED] ใช้ CustomDropdown แทน _buildDropdown เดิม
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Type",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 6),
                    CustomDropdown<String>(
                      hintText: 'Select type',
                      items: _activityTypes,
                      initialItem: _selectedType,
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value;
                        });
                      },
                      decoration: _getDropdownDecoration(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Status",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 6),
                    CustomDropdown<String>(
                      hintText: 'Select status',
                      items: _statuses,
                      initialItem: _selectedStatus,
                      onChanged: (value) {
                        setState(() {
                          _selectedStatus = value;
                        });
                      },
                      decoration: _getDropdownDecoration(),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_selectedType == 'Other') ...[
            const SizedBox(height: 16),
            _buildTextField(controller: _customTypeCtrl, label: "Specify Type"),
          ],

          const SizedBox(height: 16),
          TextFormField(
            controller: _descCtrl,
            maxLines: null,
            minLines: 5,
            decoration: InputDecoration(
              labelText: "Description / Objectives",
              alignLabelWithHint: true,
              fillColor: const Color(0xFFF9FAFB),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: Text(
              "Compulsory Activity",
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              "System will auto-count participants based on target.",
              style: GoogleFonts.inter(fontSize: 12),
            ),
            value: _isCompulsory == 1,
            activeColor: const Color(0xFF4A80FF),
            onChanged: (val) {
              setState(() {
                _isCompulsory = val ? 1 : 0;
                if (_isCompulsory == 1) {
                  _fetchTargetCount(); // Trigger count when toggled on
                }
              });
            },
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // [UPDATED] Widget การ์ดวันเวลาที่เรียกใช้ปฏิทินใหม่
  Widget _buildDateTimeLocationCard() {
    return _buildCard(
      child: Column(
        children: [
          InkWell(
            onTap: _openSmartCalendar, // เรียกฟังก์ชันใหม่
            borderRadius: BorderRadius.circular(12),
            child: _buildReadOnlyField(
              "Date",
              DateFormat(
                'EEE, d MMMM y',
              ).format(_selectedDate ?? DateTime.now()),
              Icons.calendar_month_rounded, // Icon ใหม่สวยกว่า
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTimeButton("Start", _startTime, true)),
              const SizedBox(width: 16),
              Expanded(child: _buildTimeButton("End", _endTime, false)),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _locationCtrl,
            label: "Location *",
            icon: Icons.place_outlined,
          ),
        ],
      ),
    );
  }

  // [NEW] Helper สำหรับ DayNightTimePicker
  // ไฟล์: lib/screens/organizer_screens/activities/activity_create_screen.dart

  // [UPDATED] แก้ไขฟังก์ชันนี้เพื่อใช้ Theme แบบที่คุณต้องการ
  Widget _buildTimeButton(String label, TimeOfDay? time, bool isStart) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          showPicker(
            context: context,
            value: time != null
                ? Time(hour: time.hour, minute: time.minute)
                : Time(hour: 9, minute: 0),
            onChange: (Time newTime) {
              setState(() {
                if (isStart) {
                  _startTime = TimeOfDay(
                    hour: newTime.hour,
                    minute: newTime.minute,
                  );
                } else {
                  _endTime = TimeOfDay(
                    hour: newTime.hour,
                    minute: newTime.minute,
                  );
                }
              });
            },
            sunrise: Time(hour: 6, minute: 0),
            sunset: Time(hour: 18, minute: 0),
            duskSpanInMinutes: 120,

            // [FIXED] เปลี่ยนเป็น false เพื่อให้แสดง AM/PM
            is24HrFormat: false,

            accentColor: const Color(0xFF4A80FF),
            okText: "Select",
            cancelText: "Cancel",
            // เพิ่มเพื่อให้ UI ดูทันสมัยขึ้น (Optional)
            iosStylePicker: true,
          ),
        );
      },
      child: _buildReadOnlyField(
        label,
        // format(context) จะแสดง AM/PM ตาม Locale เครื่องให้อัตโนมัติ
        time?.format(context) ?? "--:--",
        isStart ? Icons.access_time : Icons.access_time_filled,
      ),
    );
  }

  Widget _buildAgendaCard() {
    return _buildCard(
      child: Column(
        children: [
          if (_agendaItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  "No sessions added yet.",
                  style: GoogleFonts.inter(color: Colors.grey),
                ),
              ),
            ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _agendaItems.removeAt(oldIndex);
                _agendaItems.insert(newIndex, item);
              });
            },
            children: [
              for (int i = 0; i < _agendaItems.length; i++)
                ListTile(
                  key: ValueKey(i),
                  tileColor: Colors.grey[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  leading: Text(
                    _agendaItems[i]['time'] ?? '',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  title: Text(_agendaItems[i]['title'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => setState(() => _agendaItems.removeAt(i)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _showAddAgendaDialog,
            icon: const Icon(Icons.add),
            label: const Text("Add Session"),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4A80FF),
              side: const BorderSide(color: Color(0xFF4A80FF)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddAgendaDialog() {
    final timeCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final detailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Session"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: timeCtrl,
              decoration: InputDecoration(
                labelText: "Time (e.g. 09:00 AM)",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: () {
                    Navigator.of(context).push(
                      showPicker(
                        context: context,
                        value: Time(hour: 9, minute: 0),
                        onChange: (Time newTime) {
                          // [UPDATED] แปลงเวลาเป็นแบบมี AM/PM
                          final timeOfDay = TimeOfDay(
                            hour: newTime.hour,
                            minute: newTime.minute,
                          );
                          timeCtrl.text = timeOfDay.format(context);
                        },
                        sunrise: Time(hour: 6, minute: 0),
                        sunset: Time(hour: 18, minute: 0),
                        duskSpanInMinutes: 120,

                        // [FIXED] เปลี่ยนเป็น false
                        is24HrFormat: false,

                        accentColor: const Color(0xFF4A80FF),
                        okText: "Select",
                        cancelText: "Cancel",
                        iosStylePicker: true,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildTextField(controller: titleCtrl, label: "Title"),
            const SizedBox(height: 10),
            _buildTextField(controller: detailCtrl, label: "Details"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (timeCtrl.text.isNotEmpty && titleCtrl.text.isNotEmpty) {
                setState(
                  () => _agendaItems.add({
                    "time": timeCtrl.text,
                    "title": titleCtrl.text,
                    "detail": detailCtrl.text,
                  }),
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetAudienceCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Who can join?",
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Radio<String>(
                value: 'all',
                groupValue: _targetType,
                onChanged: (v) {
                  setState(() => _targetType = v!);
                  _fetchTargetCount();
                },
              ),
              const Text("All Employees"),
              const SizedBox(width: 16),
              Radio<String>(
                value: 'specific',
                groupValue: _targetType,
                onChanged: (v) {
                  setState(() => _targetType = v!);
                  _fetchTargetCount();
                },
              ),
              const Text("Specific Group"),
            ],
          ),
          if (_targetType == 'specific') ...[
            const SizedBox(height: 16),
            Text("Departments", style: GoogleFonts.inter(fontSize: 12)),
            const SizedBox(height: 6),
            CustomDropdown<String>.multiSelect(
              hintText: 'Select departments',
              items: _dbDepartments,
              initialItems: _selectedTargetDepts,
              onListChanged: (value) {
                setState(() => _selectedTargetDepts = value);
                _fetchTargetCount();
              },
              decoration: _getDropdownDecoration(),
            ),
            const SizedBox(height: 12),
            Text("Positions", style: GoogleFonts.inter(fontSize: 12)),
            const SizedBox(height: 6),
            CustomDropdown<String>.multiSelect(
              hintText: 'Select positions',
              items: _dbPositions,
              initialItems: _selectedTargetPositions,
              onListChanged: (value) {
                setState(() => _selectedTargetPositions = value);
                _fetchTargetCount();
              },
              decoration: _getDropdownDecoration(),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _isCompulsory == 1
                    ? Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Max People (Auto)",
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                _isCounting
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        "$_autoCountedParticipants",
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                              ],
                            ),
                            const Icon(
                              Icons.lock_outline,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      )
                    : _buildTextField(
                        controller: _maxParticipantsCtrl,
                        label: "Max People",
                        isNumber: true,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? "Required" : null,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _pointsCtrl,
                  label: "Points per Person",
                  isNumber: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _feeCtrl,
            label: "Fee (Baht)",
            isNumber: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMoreDetailsCard() {
    return _buildCard(
      title: "Additional Details",
      icon: Icons.playlist_add_check_circle_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Organizer & Host"),

          // [UPDATED] Hosting Department Dropdown
          Text(
            "Hosting Department",
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 6),
          CustomDropdown<String>(
            hintText: 'Select Department',
            items: _dbDepartments.isEmpty ? ['Other'] : _dbDepartments,
            initialItem: _selectedHostDept,
            onChanged: (value) {
              setState(() => _selectedHostDept = value);
            },
            decoration: _getDropdownDecoration(),
          ),

          if (_selectedHostDept == 'Other') ...[
            const SizedBox(height: 20),
            _buildTextField(
              controller: _customHostDeptCtrl,
              label: "Specify Department Name",
            ),
          ],
          const SizedBox(height: 20),
          _buildTextField(
            controller: _hostCtrl,
            label: "Event Host (Company/Unit)",
            icon: Icons.business,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _guestCtrl,
            label: "Guest Speaker",
            icon: Icons.record_voice_over,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _organizerNameCtrl,
            label: "Organizer Contact Name",
            icon: Icons.person,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _contactCtrl,
            label: "Contact Info (Tel/Email)",
            icon: Icons.contact_phone,
          ),
          // ... (Logistics ส่วนที่เหลือคงเดิม) ...
          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 10),
          _buildSectionHeader("Logistics & Facilities"),
          _buildTextField(
            controller: _foodCtrl,
            label: "Food Provided",
            icon: Icons.restaurant,
            hint: "e.g. Lunch Box, Snack",
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _travelCtrl,
            label: "Travel / Transportation",
            icon: Icons.directions_bus,
            hint: "e.g. Van at BTS Ari",
          ),
          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 10),
          _buildSectionHeader("Requirements & Notes"),
          _buildTextField(
            controller: _conditionCtrl,
            label: "Conditions / Requirements",
            icon: Icons.rule,
            hint: "e.g. Laptop required",
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _moreCtrl,
            label: "Note / More Details",
            maxLines: 3,
            hint: "Any other information...",
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF4A80FF),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCard({String? title, IconData? icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: const Color(0xFF4A80FF), size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isNumber = false,
    int maxLines = 1,
    IconData? icon,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
        labelStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: Colors.grey)
            : null,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
              ),
              Text(
                value,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
