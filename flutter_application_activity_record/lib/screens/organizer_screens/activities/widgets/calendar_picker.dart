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
  final bool allowPast;
  final bool singleSelection;

  const CalendarPicker({
    super.key,
    required this.mode,
    this.initialMonth,
    this.initialRange,
    this.initialMulti,
    this.onRangeChanged,
    this.onMultiChanged,
    this.allowPast = false,
    this.singleSelection = false,
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
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
              Row(
                children: [
                  InkWell(
                    onTap: _pickMonth,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: organizerBg, borderRadius: BorderRadius.circular(12)),
                      child: Text(_monthName(_visibleMonth.month), style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _pickYear,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: organizerBg, borderRadius: BorderRadius.circular(12)),
                      child: Text('${_visibleMonth.year}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right)),
            ],
          ),
          const SizedBox(height: 6),
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
          const SizedBox(height: 4),
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
      rows.add(const SizedBox(height: 4));
    }
    return rows;
  }

  Widget _buildDayCell(DateTime? day) {
    if (day == null) {
      return const SizedBox(height: 40);
    }
    final isSelected = _isSelected(day);
    final isInRange = _inRange(day);
    final isPast = _stripTime(day).isBefore(_stripTime(DateTime.now()));
    final bgColor = isSelected
        ? chipSelectedYellow
        : (isInRange ? chipSelectedYellow.withOpacity(0.25) : Colors.transparent);
    final textColor = (!widget.allowPast && isPast)
        ? Colors.grey
        : (isSelected ? Colors.black : Colors.black87);
    return GestureDetector(
      onTap: (!widget.allowPast && isPast) ? null : () => _onTapDay(day),
      child: Container(
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: (!widget.allowPast && isPast)
              ? Border.all(color: Colors.grey.withOpacity(0.3))
              : null,
        ),
        alignment: Alignment.center,
        child: Text('${day.day}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textColor)),
      ),
    );
  }

  void _pickMonth() async {
    final months = List<int>.generate(12, (i) => i + 1);
    await showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: GridView.count(
            crossAxisCount: 3,
            padding: const EdgeInsets.all(12),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: months.map((m) {
              return InkWell(
                onTap: () {
                  setState(() {
                    _visibleMonth = DateTime(_visibleMonth.year, m, 1);
                  });
                  Navigator.pop(ctx);
                },
                child: Container(
                  decoration: BoxDecoration(color: organizerBg, borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: Text(_monthName(m), style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _pickYear() async {
    final current = DateTime.now().year;
    final years = List<int>.generate(current - 1900 + 1, (i) => current - i);
    await showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemBuilder: (c, i) {
              final y = years[i];
              return ListTile(
                title: Text('$y', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                onTap: () {
                  setState(() {
                    _visibleMonth = DateTime(y, _visibleMonth.month, 1);
                  });
                  Navigator.pop(ctx);
                },
              );
            },
            separatorBuilder: (c, i) => const Divider(height: 1),
            itemCount: years.length,
          ),
        );
      },
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
      if (widget.singleSelection) {
        _multi
          ..clear()
          ..add(d);
      } else {
        if (_multi.contains(d)) {
          _multi.remove(d);
        } else {
          _multi.add(d);
        }
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