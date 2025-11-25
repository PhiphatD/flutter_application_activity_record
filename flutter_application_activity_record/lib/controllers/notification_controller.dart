import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend_api/config.dart';

class NotificationController {
  // Singleton Instance: สร้างตัวเดียวใช้ทั่วแอป
  static final NotificationController _instance =
      NotificationController._internal();
  factory NotificationController() => _instance;
  NotificationController._internal();

  // [CORE] ตัวแปรเก็บตัวเลขที่เป็น ValueNotifier (เมื่อค่าเปลี่ยน UI จะเปลี่ยนเอง)
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  // ฟังก์ชันดึงตัวเลขล่าสุดจาก Server
  Future<void> fetchUnreadCount({required String role}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final empId = prefs.getString('empId') ?? "";

      if (empId.isEmpty) return;

      final url = Uri.parse(
        '${Config.apiUrl}/notifications/$empId/unread?role=$role',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final int count = data['count'] ?? 0;

        // [UPDATE] อัปเดตตัวเลข -> UI ทุกจุดที่ฟังอยู่จะเปลี่ยนทันที
        unreadCount.value = count;
        print("🔔 Updated Unread Count: $count");
      }
    } catch (e) {
      print("Error fetching unread count: $e");
    }
  }

  // ฟังก์ชันลดจำนวนลง 1 ทันที (ใช้เมื่อกดอ่านแล้ว เพื่อความลื่นไหล)
  void decreaseCount() {
    if (unreadCount.value > 0) {
      unreadCount.value--;
    }
  }

  // ฟังก์ชันเคลียร์ค่า (เมื่อ Logout)
  void clear() {
    unreadCount.value = 0;
  }
}
