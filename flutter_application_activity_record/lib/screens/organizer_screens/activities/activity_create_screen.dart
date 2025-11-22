import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:day_night_time_picker/day_night_time_picker.dart';
import 'package:day_night_time_picker/lib/state/time.dart';

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
  final _imageUrlCtrl = TextEditingController(); // ACT_IMAGE (Cover URL)
  List<PlatformFile> _selectedFiles = []; // For additional attachments

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

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
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
      _imageUrlCtrl.text = act['ACT_IMAGE'] ?? '';
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

  // --- File Picker Logic ---
  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf'],
      );

      if (result != null) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error picking file: $e")));
    }
  }

  void _removeFile(int index) {
    setState(() => _selectedFiles.removeAt(index));
  }

  // --- Submit Logic ---
  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;
    if (_locationCtrl.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter location")));
      return;
    }

    setState(() => _isSubmitting = true);

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

        // Full DB Mapping
        "ACT_IMAGE": _imageUrlCtrl.text,
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
            // 1. Cover Image
            _buildSectionTitle("Cover Image"),
            _buildCoverImageSection(),
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

            // 7. Attachments (Multiple Files)
            _buildSectionTitle("Documents & Files"),
            _buildAttachmentsCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- Widgets ---

  Widget _buildCoverImageSection() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        image: _imageUrlCtrl.text.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(_imageUrlCtrl.text),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Stack(
        children: [
          if (_imageUrlCtrl.text.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_outlined, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    "Enter URL below",
                    style: GoogleFonts.inter(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          Positioned(
            bottom: 10,
            left: 10,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _imageUrlCtrl,
                decoration: const InputDecoration(
                  hintText: "Paste Image URL...",
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.link),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                onChanged: (val) => setState(() {}),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return _buildCard(
      child: Column(
        children: [
          _buildTextField(
            controller: _nameCtrl,
            label: "Activity Name *",
            validator: (v) => v!.isEmpty ? "Required" : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  "Type",
                  _selectedType,
                  _activityTypes,
                  (v) => setState(() => _selectedType = v),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdown(
                  "Status",
                  _selectedStatus,
                  _statuses,
                  (v) => setState(() => _selectedStatus = v),
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
              "Required for target employees",
              style: GoogleFonts.inter(fontSize: 12),
            ),
            value: _isCompulsory == 1,
            activeColor: const Color(0xFF4A80FF),
            onChanged: (val) => setState(() => _isCompulsory = val ? 1 : 0),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // [UPDATED] ใช้ DayNightTimePicker แทน showTimePicker
  Widget _buildDateTimeLocationCard() {
    return _buildCard(
      child: Column(
        children: [
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
            child: _buildReadOnlyField(
              "Date",
              DateFormat(
                'EEE, d MMMM y',
              ).format(_selectedDate ?? DateTime.now()),
              Icons.calendar_month,
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
            icon: Icons.place,
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
            is24HrFormat: true,
            accentColor: const Color(0xFF4A80FF),
            okText: "Select",
            cancelText: "Cancel",
          ),
        );
      },
      child: _buildReadOnlyField(
        label,
        time?.format(context) ?? "--:--", // แสดงผลเวลาใน UI เดิม
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
            // [NEW] ใช้ DayNightTimePicker ใน Dialog นี้ด้วยก็ดีครับ แต่เพื่อความง่าย ใช้ TextField พิมพ์เองไปก่อนก็ได้ หรือจะเพิ่มปุ่มเลือกเวลาก็ได้
            TextField(
              controller: timeCtrl,
              decoration: InputDecoration(
                labelText: "Time (e.g. 09:00)",
                suffixIcon: IconButton(
                  icon: Icon(Icons.access_time),
                  onPressed: () {
                    Navigator.of(context).push(
                      showPicker(
                        context: context,
                        value: Time(hour: 9, minute: 0),
                        onChange: (Time newTime) {
                          final formatted =
                              "${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}";
                          timeCtrl.text = formatted;
                        },
                        sunrise: Time(hour: 6, minute: 0),
                        sunset: Time(hour: 18, minute: 0),
                        duskSpanInMinutes: 120,
                        is24HrFormat: true,
                        accentColor: const Color(0xFF4A80FF),
                        okText: "Select",
                        cancelText: "Cancel",
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
        children: [
          Row(
            children: [
              Radio<String>(
                value: 'all',
                groupValue: _targetType,
                onChanged: (v) => setState(() => _targetType = v!),
              ),
              const Text('Everyone'),
              const SizedBox(width: 20),
              Radio<String>(
                value: 'specific',
                groupValue: _targetType,
                onChanged: (v) => setState(() => _targetType = v!),
              ),
              const Text('Specific Group'),
            ],
          ),
          if (_targetType == 'specific') ...[
            const Divider(),
            const Text("Departments:"),
            Wrap(
              spacing: 8,
              children: _dbDepartments.where((d) => d != 'Other').map((dep) {
                final isSel = _selectedTargetDepts.contains(dep);
                return FilterChip(
                  label: Text(dep),
                  selected: isSel,
                  onSelected: (val) => setState(
                    () => val
                        ? _selectedTargetDepts.add(dep)
                        : _selectedTargetDepts.remove(dep),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            const Text("Positions:"),
            Wrap(
              spacing: 8,
              children: _dbPositions.map((pos) {
                final isSel = _selectedTargetPositions.contains(pos);
                return FilterChip(
                  label: Text(pos),
                  selected: isSel,
                  onSelected: (val) => setState(
                    () => val
                        ? _selectedTargetPositions.add(pos)
                        : _selectedTargetPositions.remove(pos),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _maxParticipantsCtrl,
                  label: "Max People",
                  isNumber: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _pointsCtrl,
                  label: "Points",
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
          _buildDropdownField(
            label: 'Hosting Department',
            value: _selectedHostDept,
            items: _dbDepartments.isEmpty ? ['Other'] : _dbDepartments,
            onChanged: (val) => setState(() => _selectedHostDept = val),
            hint: 'Select Department',
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
            hint: "e.g. Laptop required, Casual dress code",
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

  Widget _buildAttachmentsCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedFiles.isNotEmpty) ...[
            ..._selectedFiles.asMap().entries.map((entry) {
              final index = entry.key;
              final file = entry.value;
              final isImage = [
                'jpg',
                'jpeg',
                'png',
              ].contains(file.extension?.toLowerCase());
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    image: isImage && file.path != null
                        ? DecorationImage(
                            image: FileImage(File(file.path!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: !isImage
                      ? const Icon(Icons.insert_drive_file, color: Colors.grey)
                      : null,
                ),
                title: Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text("${(file.size / 1024).toStringAsFixed(1)} KB"),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _removeFile(index),
                ),
              );
            }).toList(),
            const SizedBox(height: 12),
          ],
          InkWell(
            onTap: _pickFiles,
            child: Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4A80FF).withOpacity(0.5),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.upload_file, color: Color(0xFF4A80FF)),
                  Text(
                    "Upload Images / PDF",
                    style: GoogleFonts.inter(
                      color: const Color(0xFF4A80FF),
                      fontWeight: FontWeight.w500,
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

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : null,
              isExpanded: true,
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?)? onChanged,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: value,
            isExpanded: true,
            items: items.map((String item) {
              return DropdownMenuItem<String>(value: item, child: Text(item));
            }).toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
            ),
          ),
        ],
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
