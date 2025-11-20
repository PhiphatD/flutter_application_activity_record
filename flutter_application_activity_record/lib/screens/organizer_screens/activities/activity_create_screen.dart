import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences

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
  // URL API (Ngrok)
  final String baseUrl = "https://numerably-nonevincive-kyong.ngrok-free.dev";
  bool _isSubmitting = false;
  bool _isLoadingData = true;

  // --- Data Lists from DB ---
  List<String> _dbDepartments = [];
  List<String> _dbPositions = [];

  // --- Controllers & State ---
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // Hosting Department (Dropdown + Other)
  String? _selectedHostDept;
  final _customHostDeptCtrl = TextEditingController();

  final _locationCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController();

  // Type Dropdown
  String? _selectedType = 'Training';
  final List<String> _activityTypes = [
    'Training',
    'Seminar',
    'Workshop',
    'Other',
  ];
  final _customTypeCtrl = TextEditingController();

  // Status Dropdown
  String? _selectedStatus = 'Open';
  final List<String> _statuses = ['Open', 'Full', 'Closed', 'Canceled'];

  // Date & Time
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  DateTime? _selectedDate; // [NEW] เพิ่มตัวแปรวันที่

  // Organizer Info
  final _guestCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  final _organizerNameCtrl = TextEditingController(); // จะดึงชื่อจาก Prefs
  final _contactCtrl = TextEditingController();
  final _maxParticipantsCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();

  // Target Audience Logic
  String _targetType = 'all'; // all, specific
  List<String> _selectedTargetDepts = [];
  List<String> _selectedTargetPositions = [];

  // Details
  final _travelCtrl = TextEditingController();
  final _foodCtrl = TextEditingController();
  final _moreCtrl = TextEditingController();
  final _conditionCtrl = TextEditingController();
  int _isCompulsory = 0;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  // โหลดข้อมูลเริ่มต้น (Dropdown + User Info + Activity Data if Edit)
  Future<void> _fetchInitialData() async {
    try {
      // 1. Fetch Departments
      final depRes = await http.get(Uri.parse('$baseUrl/departments'));
      if (depRes.statusCode == 200) {
        final List data = jsonDecode(utf8.decode(depRes.bodyBytes));
        setState(() {
          _dbDepartments = data
              .map<String>((e) => e['name'].toString())
              .toList();
          _dbDepartments.add('Other');
        });
      }

      // 2. Fetch Positions
      final posRes = await http.get(Uri.parse('$baseUrl/positions'));
      if (posRes.statusCode == 200) {
        final List data = jsonDecode(utf8.decode(posRes.bodyBytes));
        setState(() {
          _dbPositions = data.map<String>((e) => e.toString()).toList();
        });
      }

      // 3. Load User Info from Prefs (Set default Organizer Name)
      final prefs = await SharedPreferences.getInstance();
      if (!widget.isEdit) {
        _organizerNameCtrl.text = prefs.getString('name') ?? 'You';
      }

      // 4. Load Activity Data (ถ้าเป็น Edit)
      if (widget.initialData != null) {
        _loadActivityData();
      }
    } catch (e) {
      print("Error fetching initial data: $e");
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  void _loadActivityData() {
    final act = widget.initialData!['ACTIVITY'];
    final org = widget.initialData!['ORGANIZER'];
    final sessions = widget.initialData!['SESSIONS'] as List?;

    if (act != null) {
      _nameCtrl.text = act['ACT_NAME'] ?? '';
      _descCtrl.text = act['ACT_DESCRIPTIONS'] ?? '';
      _pointsCtrl.text = (act['ACT_POINT'] ?? 0).toString();

      // Load Type
      String type = act['ACT_TYPE'] ?? 'Training';
      if (!_activityTypes.contains(type)) {
        _selectedType = 'Other';
        _customTypeCtrl.text = type;
      } else {
        _selectedType = type;
      }

      _selectedStatus = act['ACT_STATUS'] ?? 'Open';

      // Load Host Dept
      String depName = act['DEP_ID'] ?? '';
      if (_dbDepartments.contains(depName)) {
        _selectedHostDept = depName;
      } else {
        _selectedHostDept = 'Other';
        _customHostDeptCtrl.text = depName;
      }

      _guestCtrl.text = act['ACT_GUEST_SPEAKER'] ?? '';
      _hostCtrl.text = act['ACT_EVENT_HOST'] ?? '';
      _maxParticipantsCtrl.text = (act['ACT_MAX_PARTICIPANTS'] ?? 0).toString();
      _feeCtrl.text = (act['ACT_COST'] ?? 0).toString();
      _travelCtrl.text = act['ACT_TRAVEL_INFO'] ?? '';
      _foodCtrl.text = act['ACT_FOOD_INFO'] ?? '';
      _moreCtrl.text = act['ACT_MORE_DETAILS'] ?? '';
      _conditionCtrl.text = act['ACT_PARTICIPATION_CONDITION'] ?? '';
      _isCompulsory = (act['ACT_ISCOMPULSORY'] ?? 0) == 1 ? 1 : 0;

      // Load Target Criteria
      if (act['ACT_TARGET_CRITERIA'] != null) {
        try {
          // API อาจส่งมาเป็น String หรือ Map แล้วแต่การ parse
          final criteria = act['ACT_TARGET_CRITERIA'] is String
              ? jsonDecode(act['ACT_TARGET_CRITERIA'])
              : act['ACT_TARGET_CRITERIA'];

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
      // Load Date
      if (first['SESSION_DATE'] != null) {
        _selectedDate = DateTime.parse(first['SESSION_DATE']);
      }
      // Load Time
      if (first['START_TIME'] != null)
        _startTime = _parseTime(first['START_TIME']);
      if (first['END_TIME'] != null) _endTime = _parseTime(first['END_TIME']);
    }
  }

  TimeOfDay? _parseTime(String s) {
    if (s.isEmpty) return null;
    try {
      final parts = s.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  // --- Logic การบันทึกข้อมูล ---
  Future<void> _submitData() async {
    if (_nameCtrl.text.isEmpty || _locationCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in Name and Location")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // 1. Prepare Data
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

    // ใช้ _selectedDate หรือ Default อีก 5 วัน
    final sessionDate =
        _selectedDate ?? DateTime.now().add(const Duration(days: 5));

    // Format Time to HH:mm
    final startStr = _startTime != null
        ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
        : "09:00";
    final endStr = _endTime != null
        ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
        : "12:00";

    final body = {
      "ACTIVITY": {
        "ACT_NAME": _nameCtrl.text,
        "ACT_TYPE": finalType,
        "ACT_DESCRIPTIONS": _descCtrl.text,
        "ACT_POINT": int.tryParse(_pointsCtrl.text) ?? 0,
        "ACT_MAX_PARTICIPANTS": int.tryParse(_maxParticipantsCtrl.text) ?? 0,
        "DEP_ID": finalHostDept ?? 'General',
        "ACT_TARGET_CRITERIA": jsonEncode(targetCriteria),
        "ACT_STATUS": _selectedStatus,
        "ACT_GUEST_SPEAKER": _guestCtrl.text,
        "ACT_EVENT_HOST": _hostCtrl.text,
        "ACT_COST": double.tryParse(_feeCtrl.text) ?? 0.0,
        "ACT_TRAVEL_INFO": _travelCtrl.text,
        "ACT_FOOD_INFO": _foodCtrl.text,
        "ACT_MORE_DETAILS": _moreCtrl.text,
        "ACT_PARTICIPATION_CONDITION": _conditionCtrl.text,
        "ACT_ISCOMPULSORY": _isCompulsory,
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

    // 2. Send API
    try {
      http.Response response;
      final prefs = await SharedPreferences.getInstance();

      if (widget.isEdit && widget.actId != null) {
        // Update (PUT)
        response = await http.put(
          Uri.parse('$baseUrl/activities/${widget.actId}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
      } else {
        // Create (POST)
        // ดึง empId จากเครื่องเพื่อส่งไปผูกกับ Organizer
        final empId = prefs.getString('empId') ?? '';

        response = await http.post(
          Uri.parse('$baseUrl/activities?emp_id=$empId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.isEdit ? "Updated Successfully" : "Created Successfully",
              ),
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        final err = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? 'Unknown Error');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _customHostDeptCtrl.dispose();
    _locationCtrl.dispose();
    _pointsCtrl.dispose();
    _customTypeCtrl.dispose();
    _guestCtrl.dispose();
    _hostCtrl.dispose();
    _organizerNameCtrl.dispose();
    _contactCtrl.dispose();
    _maxParticipantsCtrl.dispose();
    _feeCtrl.dispose();
    _travelCtrl.dispose();
    _foodCtrl.dispose();
    _moreCtrl.dispose();
    _conditionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: const BackButton(color: Colors.black),
        title: Text(
          widget.isEdit ? 'Edit Activity' : 'Create Activity',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: _submitData,
              child: Text(
                "Save",
                style: GoogleFonts.inter(
                  color: const Color(0xFF4A80FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Section 1: Basic Info ---
              _buildSectionTitle('Basic Information'),
              _buildTextField(
                controller: _nameCtrl,
                label: 'Activity Name *',
                hint: 'Ex. AI Workshop 2025',
              ),

              // Activity Type
              _buildDropdownField(
                label: 'Activity Type',
                value: _selectedType,
                items: _activityTypes,
                onChanged: (val) => setState(() => _selectedType = val),
                hint: 'Select Type',
              ),
              if (_selectedType == 'Other')
                _buildTextField(
                  controller: _customTypeCtrl,
                  label: 'Specify Type *',
                  hint: 'Ex. Outing',
                ),

              _buildTextField(
                controller: _descCtrl,
                label: 'Description',
                hint: 'Brief detail...',
                maxLines: 3,
              ),

              // Status
              _buildDropdownField(
                label: 'Status',
                value: _selectedStatus,
                items: _statuses,
                onChanged: (val) => setState(() => _selectedStatus = val),
                hint: 'Status',
              ),

              const SizedBox(height: 24),
              // --- Section 2: Date & Location ---
              _buildSectionTitle('Date & Location'),

              // Date Picker Button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedDate != null
                                  ? "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}"
                                  : "Select Date",
                              style: GoogleFonts.inter(),
                            ),
                            const Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Row(
                children: [
                  Expanded(
                    child: _buildTimeButton('Start Time', _startTime, true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTimeButton('End Time', _endTime, false),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _locationCtrl,
                label: 'Location *',
                hint: 'Ex. Room 303',
              ),

              const SizedBox(height: 24),
              // --- Section 3: Host & Organizer ---
              _buildSectionTitle('Host & Organizer'),

              // Hosting Dept
              _buildDropdownField(
                label: 'Hosting Department *',
                value: _selectedHostDept,
                items: _dbDepartments.isEmpty ? ['Other'] : _dbDepartments,
                onChanged: (val) => setState(() => _selectedHostDept = val),
                hint: 'Who is organizing?',
              ),
              if (_selectedHostDept == 'Other')
                _buildTextField(
                  controller: _customHostDeptCtrl,
                  label: 'New Department Name *',
                  hint: 'Ex. Innovation Lab',
                ),

              _buildTextField(
                controller: _hostCtrl,
                label: 'Event Host (Company/Unit)',
                hint: 'Ex. Microsoft Thailand',
              ),
              _buildTextField(
                controller: _guestCtrl,
                label: 'Guest Speaker',
                hint: 'Ex. Mr. John Doe',
              ),
              _buildTextField(
                controller: _organizerNameCtrl,
                label: 'Organizer Name',
                hint: 'Your Name',
              ),
              _buildTextField(
                controller: _contactCtrl,
                label: 'Contact Info',
                hint: 'Email or Phone',
              ),

              const SizedBox(height: 24),
              // --- Section 4: Target Audience ---
              _buildSectionTitle('Target Audience & Quota'),

              Text(
                'Who can join?',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Departments:',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: _dbDepartments.where((d) => d != 'Other').map(
                          (dep) {
                            final isSel = _selectedTargetDepts.contains(dep);
                            return FilterChip(
                              label: Text(dep),
                              selected: isSel,
                              onSelected: (val) {
                                setState(() {
                                  if (val)
                                    _selectedTargetDepts.add(dep);
                                  else
                                    _selectedTargetDepts.remove(dep);
                                });
                              },
                            );
                          },
                        ).toList(),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Positions:',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: _dbPositions.map((pos) {
                          final isSel = _selectedTargetPositions.contains(pos);
                          return FilterChip(
                            label: Text(pos),
                            selected: isSel,
                            onSelected: (val) {
                              setState(() {
                                if (val)
                                  _selectedTargetPositions.add(pos);
                                else
                                  _selectedTargetPositions.remove(pos);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _maxParticipantsCtrl,
                      label: 'Max Participants',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _pointsCtrl,
                      label: 'Points',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              _buildTextField(
                controller: _feeCtrl,
                label: 'Participation Fee (Baht)',
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 24),
              // --- Section 5: More Details ---
              _buildSectionTitle('More Details'),
              _buildTextField(
                controller: _foodCtrl,
                label: 'Food Provided',
                hint: 'Ex. Lunch Box',
              ),
              _buildTextField(
                controller: _travelCtrl,
                label: 'Travel Arrangement',
                hint: 'Ex. Van at BTS Ari',
              ),
              _buildTextField(
                controller: _moreCtrl,
                label: 'Note / More Details',
                maxLines: 2,
              ),
              _buildTextField(
                controller: _conditionCtrl,
                label: 'Condition',
                hint: 'Ex. Bring your own laptop',
              ),

              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  "This is a Compulsory Activity",
                  style: GoogleFonts.inter(),
                ),
                value: _isCompulsory == 1,
                onChanged: (val) =>
                    setState(() => _isCompulsory = val! ? 1 : 0),
                controlAffinity: ListTileControlAffinity.leading,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- Custom Widgets ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Divider(color: Colors.grey[300], thickness: 1),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
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
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF222222),
            ),
            items: items.map((String item) {
              return DropdownMenuItem<String>(value: item, child: Text(item));
            }).toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeButton(String label, TimeOfDay? time, bool isStart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final res = await showTimePicker(
              context: context,
              initialTime: time ?? const TimeOfDay(hour: 9, minute: 0),
            );
            if (res != null) {
              setState(() {
                if (isStart)
                  _startTime = res;
                else
                  _endTime = res;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time?.format(context) ?? 'Select',
                  style: GoogleFonts.inter(),
                ),
                const Icon(Icons.access_time, size: 18, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
