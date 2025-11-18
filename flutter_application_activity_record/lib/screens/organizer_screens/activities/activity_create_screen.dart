import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application_activity_record/theme/app_colors.dart';
import 'widgets/calendar_picker.dart';

class CreateActivityScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final bool isEdit;
  const CreateActivityScreen({
    super.key,
    this.initialData,
    this.isEdit = false,
  });

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  final PageController _pageController = PageController();
  int _step = 0;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController();
  String _type = 'Training';
  bool _useRange = true;
  DateTimeRange? _dateRange;
  final List<DateTime> _multipleDates = [];
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final _guestCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  final _organizerCtrl = TextEditingController(text: 'You');
  final _contactCtrl = TextEditingController();
  final _maxParticipantsCtrl = TextEditingController();
  String _department = 'IT';
  final List<String> _departments = const [
    'All Departments',
    'IT',
    'HR',
    'Marketing',
  ];
  final _feeCtrl = TextEditingController();

  final _travelCtrl = TextEditingController();
  final _foodCtrl = TextEditingController();
  final _moreCtrl = TextEditingController();
  final _conditionCtrl = TextEditingController();
  int _isCompulsory = 0;

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _pointsCtrl.dispose();
    _guestCtrl.dispose();
    _hostCtrl.dispose();
    _organizerCtrl.dispose();
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
    return Scaffold(
      backgroundColor: organizerBg,
      appBar: AppBar(
        backgroundColor: organizerBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isEdit ? 'Edit Activity' : 'Activity Management',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF375987),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [_buildStep1(), _buildStep2(), _buildStep3()],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          if (_step > 0)
            ElevatedButton(
              onPressed: () {
                setState(() => _step -= 1);
                _pageController.animateToPage(
                  _step,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              child: Text('Previous', style: GoogleFonts.poppins()),
            ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              if (_step < 2) {
                setState(() => _step += 1);
                _pageController.animateToPage(
                  _step,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                );
              } else {
                final result = _buildResult();
                Navigator.pop(context, result);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD600),
              foregroundColor: Colors.black87,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: Text(
              _step < 2 ? 'Next' : (widget.isEdit ? 'Save' : 'Create'),
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(text, style: GoogleFonts.poppins(color: Colors.black87)),
    );
  }

  InputDecoration _inputDecoration([String? hint]) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
    );
  }

  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Activity Name :'),
                      TextField(
                        controller: _nameCtrl,
                        decoration: _inputDecoration(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Type :'),
                      DropdownButtonFormField<String>(
                        value: _type,
                        items: const [
                          DropdownMenuItem(
                            value: 'Training',
                            child: Text('Training'),
                          ),
                          DropdownMenuItem(
                            value: 'Seminar',
                            child: Text('Seminar'),
                          ),
                          DropdownMenuItem(
                            value: 'Workshop',
                            child: Text('Workshop'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _type = v ?? _type),
                        decoration: _inputDecoration(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Descriptions :'),
                TextField(
                  controller: _descCtrl,
                  maxLines: 4,
                  decoration: _inputDecoration(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Location :'),
                      TextField(
                        controller: _locationCtrl,
                        decoration: _inputDecoration(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Points :'),
                      TextField(
                        controller: _pointsCtrl,
                        keyboardType: const TextInputType.numberWithOptions(),
                        decoration: _inputDecoration(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                Row(
                  children: [
                    Radio<int>(
                      value: 1,
                      groupValue: _useRange ? 1 : 0,
                      onChanged: (_) => setState(() => _useRange = true),
                    ),
                    Expanded(
                      child: Text(
                        'Select Date Range',
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Radio<int>(
                      value: 0,
                      groupValue: _useRange ? 1 : 0,
                      onChanged: (_) => setState(() => _useRange = false),
                    ),
                    Expanded(
                      child: Text(
                        'Select Multiple Date',
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CalendarPicker(
                  mode: _useRange ? CalendarMode.range : CalendarMode.multi,
                  initialRange: _dateRange,
                  initialMulti: _multipleDates,
                  onRangeChanged: (range) {
                    setState(() => _dateRange = range);
                  },
                  onMultiChanged: (dates) {
                    setState(() {
                      _multipleDates
                        ..clear()
                        ..addAll(dates);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Start Time :'),
                      _buildTimeButton(true),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('End Time :'),
                      _buildTimeButton(false),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Guest Speaker :'),
                TextField(
                  controller: _guestCtrl,
                  decoration: _inputDecoration(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Event Host :'),
                TextField(
                  controller: _hostCtrl,
                  decoration: _inputDecoration(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Organizer :'),
                TextField(
                  controller: _organizerCtrl,
                  decoration: _inputDecoration(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Organizer Contact Info :'),
                TextField(
                  controller: _contactCtrl,
                  decoration: _inputDecoration(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Max Participants :'),
                      TextField(
                        controller: _maxParticipantsCtrl,
                        keyboardType: const TextInputType.numberWithOptions(),
                        decoration: _inputDecoration(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Department :'),
                      DropdownButtonFormField<String>(
                        value: _departments.contains(_department)
                            ? _department
                            : _departments.first,
                        items: _departments
                            .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _department = v ?? _department),
                        decoration: _inputDecoration(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Participation Fee :'),
                TextField(
                  controller: _feeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _inputDecoration(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Travel Arrangement :'),
                TextField(
                  controller: _travelCtrl,
                  decoration: _inputDecoration(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Food Provided :'),
                TextField(
                  controller: _foodCtrl,
                  decoration: _inputDecoration(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('More details :'),
                TextField(
                  controller: _moreCtrl,
                  maxLines: 4,
                  decoration: _inputDecoration(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Participation Condition :'),
                TextField(
                  controller: _conditionCtrl,
                  decoration: _inputDecoration(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Radio<int>(
                  value: 0,
                  groupValue: _isCompulsory,
                  onChanged: (v) => setState(() => _isCompulsory = v ?? 0),
                ),
                Text('Normal Activity', style: GoogleFonts.poppins()),
                const SizedBox(width: 16),
                Radio<int>(
                  value: 1,
                  groupValue: _isCompulsory,
                  onChanged: (v) => setState(() => _isCompulsory = v ?? 0),
                ),
                Text('Compulsory Activity', style: GoogleFonts.poppins()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final res = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _dateRange,
    );
    if (res != null) {
      setState(() {
        _dateRange = res;
        _multipleDates.clear();
      });
    }
  }

  Future<void> _pickMultipleDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        _multipleDates.add(DateTime(picked.year, picked.month, picked.day));
        _dateRange = null;
      });
    }
  }

  Widget _buildTimeButton(bool start) {
    final value = start ? _startTime : _endTime;
    return OutlinedButton(
      onPressed: () async {
        final res = await showTimePicker(
          context: context,
          initialTime: value ?? const TimeOfDay(hour: 9, minute: 0),
        );
        if (res != null) {
          final includesToday = _selectionIncludesToday();
          if (includesToday && !_isTimeAfterNow(res)) {
            _showSnack('เวลาในวันนี้ต้องมากกว่าเวลาปัจจุบัน');
            return;
          }

          setState(() {
            if (start) {
              _startTime = res;
            } else {
              _endTime = res;
            }
          });

          if (_startTime != null && _endTime != null) {
            final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
            final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
            if (endMinutes <= startMinutes) {
              _showSnack('เวลาสิ้นสุดต้องมากกว่าเวลาเริ่มต้น');
              setState(() {
                if (!start) {
                  _endTime = null;
                }
              });
            }
          }
        }
      },
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
      child: Text(
        value != null ? value.format(context) : 'Select',
        style: GoogleFonts.poppins(),
      ),
    );
  }

  Map<String, dynamic> _buildResult() {
    List<Map<String, dynamic>> sessions = [];
    if (_useRange &&
        _dateRange != null &&
        _startTime != null &&
        _endTime != null) {
      DateTime cur = _dateRange!.start;
      while (!cur.isAfter(_dateRange!.end)) {
        sessions.add({
          'SESSION_DATE': DateTime(
            cur.year,
            cur.month,
            cur.day,
          ).toIso8601String(),
          'START_TIME': _startTime!.format(context),
          'END_TIME': _endTime!.format(context),
          'LOCATION': _locationCtrl.text.trim(),
        });
        cur = cur.add(const Duration(days: 1));
      }
    } else if (!_useRange &&
        _multipleDates.isNotEmpty &&
        _startTime != null &&
        _endTime != null) {
      for (final d in _multipleDates) {
        sessions.add({
          'SESSION_DATE': DateTime(d.year, d.month, d.day).toIso8601String(),
          'START_TIME': _startTime!.format(context),
          'END_TIME': _endTime!.format(context),
          'LOCATION': _locationCtrl.text.trim(),
        });
      }
    }

    return {
      'ACTIVITY': {
        'ACT_NAME': _nameCtrl.text.trim(),
        'ACT_TYPE': _type,
        'ACT_DESCRIPTIONS': _descCtrl.text.trim(),
        'ACT_POINT': int.tryParse(_pointsCtrl.text.trim()) ?? 0,
        'ACT_GUEST_SPEAKER': _guestCtrl.text.trim(),
        'ACT_EVENT_HOST': _hostCtrl.text.trim(),
        'ACT_MAX_PARTICIPANTS':
            int.tryParse(_maxParticipantsCtrl.text.trim()) ?? 0,
        'DEP_ID': _department,
        'ACT_COST': double.tryParse(_feeCtrl.text.trim()) ?? 0.0,
        'ACT_TRAVEL_INFO': _travelCtrl.text.trim(),
        'ACT_FOOD_INFO': _foodCtrl.text.trim(),
        'ACT_MORE_DETAILS': _moreCtrl.text.trim(),
        'ACT_PARTICIPATION_CONDITION': _conditionCtrl.text.trim(),
        'ACT_ISCOMPULSORY': _isCompulsory,
      },
      'ORGANIZER': {
        'ORG_NAME': _organizerCtrl.text.trim(),
        'ORG_CONTACT_INFO': _contactCtrl.text.trim(),
      },
      'SESSIONS': sessions,
    };
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final act = widget.initialData!['ACTIVITY'] as Map<String, dynamic>?;
      final org = widget.initialData!['ORGANIZER'] as Map<String, dynamic>?;
      final sessions = (widget.initialData!['SESSIONS'] as List?)
          ?.cast<Map<String, dynamic>>();
      if (act != null) {
        _nameCtrl.text = (act['ACT_NAME'] ?? '').toString();
        _type = (act['ACT_TYPE'] ?? _type).toString();
        _descCtrl.text = (act['ACT_DESCRIPTIONS'] ?? '').toString();
        _pointsCtrl.text = (act['ACT_POINT'] ?? '').toString();
        _guestCtrl.text = (act['ACT_GUEST_SPEAKER'] ?? '').toString();
        _hostCtrl.text = (act['ACT_EVENT_HOST'] ?? '').toString();
        _maxParticipantsCtrl.text = (act['ACT_MAX_PARTICIPANTS'] ?? '')
            .toString();
        _department = (act['DEP_ID'] ?? _department).toString();
        if (!_departments.contains(_department)) {
          _department = _departments.first;
        }
        _feeCtrl.text = (act['ACT_COST'] ?? '').toString();
        _travelCtrl.text = (act['ACT_TRAVEL_INFO'] ?? '').toString();
        _foodCtrl.text = (act['ACT_FOOD_INFO'] ?? '').toString();
        _moreCtrl.text = (act['ACT_MORE_DETAILS'] ?? '').toString();
        _conditionCtrl.text = (act['ACT_PARTICIPATION_CONDITION'] ?? '')
            .toString();
        _isCompulsory =
            int.tryParse((act['ACT_ISCOMPULSORY'] ?? '0').toString()) ?? 0;
      }
      if (org != null) {
        _organizerCtrl.text = (org['ORG_NAME'] ?? _organizerCtrl.text)
            .toString();
        _contactCtrl.text = (org['ORG_CONTACT_INFO'] ?? '').toString();
      }
      if (sessions != null && sessions.isNotEmpty) {
        final dates = <DateTime>[];
        for (final s in sessions) {
          final dateStr = (s['SESSION_DATE'] ?? '').toString();
          if (dateStr.isNotEmpty) {
            final d = DateTime.tryParse(dateStr);
            if (d != null) dates.add(DateTime(d.year, d.month, d.day));
          }
        }
        final startStr = (sessions.first['START_TIME'] ?? '').toString();
        final endStr = (sessions.first['END_TIME'] ?? '').toString();
        _startTime = _parseTime(startStr);
        _endTime = _parseTime(endStr);
        _locationCtrl.text = (sessions.first['LOCATION'] ?? '').toString();
        if (dates.length <= 1) {
          _useRange = true;
          if (dates.isNotEmpty) {
            final d = dates.first;
            _dateRange = DateTimeRange(start: d, end: d);
          }
        } else {
          _useRange = false;
          _multipleDates
            ..clear()
            ..addAll(dates);
        }
      }
    }
  }

  TimeOfDay? _parseTime(String s) {
    if (s.isEmpty) return null;
    final parts = s.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  bool _selectionIncludesToday() {
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    if (_useRange) {
      if (_dateRange == null) return false;
      final s = DateTime(
        _dateRange!.start.year,
        _dateRange!.start.month,
        _dateRange!.start.day,
      );
      final e = DateTime(
        _dateRange!.end.year,
        _dateRange!.end.month,
        _dateRange!.end.day,
      );
      return !t.isBefore(s) && !t.isAfter(e);
    } else {
      return _multipleDates.any((d) => DateTime(d.year, d.month, d.day) == t);
    }
  }

  bool _isTimeAfterNow(TimeOfDay time) {
    final now = DateTime.now();
    final candidate = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    return candidate.isAfter(now);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
