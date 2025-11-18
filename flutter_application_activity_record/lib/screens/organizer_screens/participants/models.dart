import 'package:flutter/material.dart';

class ActivitySummary {
  final int id;
  final String name;
  final String type;
  final bool isCompulsory;
  final int points;
  final String location;
  final DateTime date;
  final TimeOfDay startTime;
  const ActivitySummary({required this.id, required this.name, required this.type, required this.isCompulsory, required this.points, required this.location, required this.date, required this.startTime});
}