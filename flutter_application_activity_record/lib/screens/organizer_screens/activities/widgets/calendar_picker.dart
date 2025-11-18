import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application_activity_record/theme/app_colors.dart';

enum CalendarMode { range, multi }

class CalendarPicker extends StatefulWidget {
  final CalendarMode mode;
  final DateTime? initialMonth;
  final DateTimeRange? initialRange;
  final List<DateTime>? initialMulti;
  final ValueChanged<DateTimeRange?>? onRangeChanged;
  final ValueChanged<List<DateTime>>? onMultiChanged;

  const CalendarPicker({
    super.key,
    required this.mode,
    this.initialMonth,
    this.initialRange,
    this.initialMulti,
    this.onRangeChanged,
    this.onMultiChanged,
  });

  @override
  State<CalendarPicker> createState() => _CalendarPickerState();
}

class _CalendarPickerState extends State<CalendarPicker> {
  late DateTime _visibleMonth;
  DateTime? _start;
  DateTime? _end;
  final Set<DateTime> _multi = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime((widget.initialMonth ?? now).year, (widget.initialMonth ?? now).month, 1);
    if (widget.initialRange != null) {
      _start = _stripTime(widget.initialRange!.start);
      _end = _stripTime(widget.initialRange!.end);
    }
    if (widget.initialMulti != null) {
      for (final d in widget.initialMulti!) {
        _multi.add(_stripTime(d));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: organizerBg, borderRadius: BorderRadius.circular(12)),
                    child: Text(_monthName(_visibleMonth.month), style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: organizerBg, borderRadius: BorderRadius.circular(12)),
                    child: Text('${_visibleMonth.year}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final d in ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'])
                Expanded(
                  child: Center(
                    child: Text(d, style: GoogleFonts.poppins(color: Colors.black54)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ..._buildWeeks(),
        ],
      ),
    );
  }

  List<Widget> _buildWeeks() {
    final firstDayOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final lastDayOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0);
    final startOffset = _weekdayIndex(firstDayOfMonth.weekday);
    final totalDays = lastDayOfMonth.day;
    final cells = <DateTime?>[];
    for (int i = 0; i < startOffset; i++) {
      cells.add(null);
    }
    for (int d = 1; d <= totalDays; d++) {
      cells.add(DateTime(_visibleMonth.year, _visibleMonth.month, d));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final rows = <Widget>[];
    for (int i = 0; i < cells.length; i += 7) {
      rows.add(Row(
        children: [
          for (int j = 0; j < 7; j++) Expanded(child: _buildDayCell(cells[i + j])),
        ],
      ));
      rows.add(const SizedBox(height: 6));
    }
    return rows;
  }

  Widget _buildDayCell(DateTime? day) {
    if (day == null) {
      return const SizedBox(height: 40);
    }
    final isSelected = _isSelected(day);
    final isInRange = _inRange(day);
    final bgColor = isSelected ? chipSelectedYellow : (isInRange ? chipSelectedYellow.withOpacity(0.25) : Colors.transparent);
    final textColor = isSelected ? Colors.black : Colors.black87;
    return GestureDetector(
      onTap: () => _onTapDay(day),
      child: Container(
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
        alignment: Alignment.center,
        child: Text('${day.day}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textColor)),
      ),
    );
  }

  void _onTapDay(DateTime day) {
    final d = _stripTime(day);
    if (widget.mode == CalendarMode.range) {
      if (_start == null || (_start != null && _end != null)) {
        _start = d;
        _end = null;
      } else if (_start != null && _end == null) {
        if (!d.isBefore(_start!)) {
          _end = d;
        } else {
          _start = d;
        }
      }
      widget.onRangeChanged?.call(_start != null && _end != null ? DateTimeRange(start: _start!, end: _end!) : null);
    } else {
      if (_multi.contains(d)) {
        _multi.remove(d);
      } else {
        _multi.add(d);
      }
      widget.onMultiChanged?.call(_multi.toList()..sort((a, b) => a.compareTo(b)));
    }
    setState(() {});
  }

  bool _isSelected(DateTime day) {
    final d = _stripTime(day);
    if (widget.mode == CalendarMode.range) {
      return d == _start || d == _end;
    }
    return _multi.contains(d);
  }

  bool _inRange(DateTime day) {
    if (widget.mode != CalendarMode.range) return false;
    if (_start == null || _end == null) return false;
    final d = _stripTime(day);
    return !d.isBefore(_start!) && !d.isAfter(_end!);
  }

  void _prevMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
    });
  }

  int _weekdayIndex(int weekday) {
    return weekday == 7 ? 6 : weekday - 1;
  }

  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  String _monthName(int m) {
    const names = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return names[m - 1];
  }
}