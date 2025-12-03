import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend_api/config.dart';

class AdminService {
  final String baseUrl = "${Config.apiUrl}/admin";

  Future<Map<String, dynamic>> getStats() async {
    try {
      // 1. ดึง ID แอดมินจากเครื่อง
      final prefs = await SharedPreferences.getInstance();
      final adminId = prefs.getString('empId') ?? '';

      // 2. ส่งไปกับ Query Param
      final response = await http.get(
        Uri.parse('$baseUrl/stats?admin_id=$adminId'),
      );

      if (response.statusCode == 200) {
        return json.decode(
          utf8.decode(response.bodyBytes),
        ); // ใช้ utf8.decode เพื่อรองรับภาษาไทยถ้ามี
      } else {
        throw Exception('Failed to load admin stats');
      }
    } catch (e) {
      print("Error fetching admin stats: $e");
      return {
        "totalEmployees": 0,
        "pendingRequests": 0,
        "totalRewards": 0,
        "totalActivities": 0,
      };
    }
  }

  Future<List<dynamic>> getAllRedemptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final adminId = prefs.getString('empId') ?? '';

      final response = await http.get(
        Uri.parse('$baseUrl/redemptions?admin_id=$adminId'),
      );
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return [];
    } catch (e) {
      print("Error fetching redemptions: $e");
      return [];
    }
  }

  // [NEW] Process Pickup Scan
  Future<Map<String, dynamic>> processPickupScan(
    String adminId,
    String redeemId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rewards/scan_pickup'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({'redeem_id': redeemId, 'admin_id': adminId}),
      );
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(error['detail'] ?? "Scan failed.");
      }
    } catch (e) {
      print("Scan Error: $e");
      throw Exception(e.toString());
    }
  }

  // [NEW] Upload Image
  Future<String?> uploadImage(File file) async {
    try {
      // Note: Upload endpoint is at root /upload/image, not under /admin
      final uploadUrl = Uri.parse('${Config.apiUrl}/upload/image');

      final multipartRequest = http.MultipartRequest('POST', uploadUrl);
      multipartRequest.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      final streamedResponse = await multipartRequest.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        // Return full URL
        return "${Config.apiUrl}${data['url']}";
      } else {
        print("Upload Failed: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Upload Error: $e");
      return null;
    }
  }

  // [REAL API] ดึงรายชื่อพนักงานทั้งหมด
  Future<List<dynamic>> getAllEmployees() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final adminId = prefs.getString('empId') ?? '';

      // ส่ง admin_id ไปด้วย
      final response = await http.get(
        Uri.parse('$baseUrl/employees?admin_id=$adminId'),
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        print("Failed to load employees: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error fetching employees: $e");
      return [];
    }
  }

  // [NEW] ดึงรายชื่อแผนก
  Future<List<String>> getDepartments() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.apiUrl}/departments'),
      );
      if (response.statusCode == 200) {
        final List data = json.decode(utf8.decode(response.bodyBytes));
        return data.map<String>((e) => e['name'].toString()).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // [NEW] ดึงรายชื่อตำแหน่ง
  Future<List<String>> getPositions() async {
    try {
      final response = await http.get(Uri.parse('${Config.apiUrl}/positions'));
      if (response.statusCode == 200) {
        final List data = json.decode(utf8.decode(response.bodyBytes));
        return data.map<String>((e) => e.toString()).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // [NEW] สร้างพนักงานใหม่
  Future<bool> createEmployee(String adminId, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('${Config.apiUrl}/admin/employees?admin_id=$adminId'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final err = json.decode(utf8.decode(response.bodyBytes));
        print("Create Failed: ${err['detail']}");
        return false;
      }
    } catch (e) {
      print("Create Emp Error: $e");
      return false;
    }
  }

  Future<List<String>> getTitles() async {
    try {
      final response = await http.get(Uri.parse('${Config.apiUrl}/titles'));
      if (response.statusCode == 200) {
        final List data = json.decode(utf8.decode(response.bodyBytes));
        return data.map<String>((e) => e.toString()).toList();
      }
      return [];
    } catch (e) {
      print("Error fetching titles: $e");
      return [];
    }
  }

  // [NEW] อัปเดตพนักงาน
  Future<bool> updateEmployee(String empId, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse(
          '${Config.apiUrl}/admin/employees/$empId',
        ), // URL ต้องตรง Backend
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Update Emp Error: $e");
      return false;
    }
  }

  // [REAL API] ลบพนักงาน
  Future<bool> deleteEmployee(String empId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final adminId = prefs.getString('empId') ?? '';

      // ส่ง admin_id ผ่าน Query Param
      final response = await http.delete(
        Uri.parse('$baseUrl/employees/$empId?admin_id=$adminId'),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print("Failed to delete employee: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Error deleting employee: $e");
      return false;
    }
  }

  // [NEW] Methods for Reward Management
  Future<List<dynamic>> getRedemptions({required String status}) async {
    // TODO: Implement actual API call
    return [];
  }

  Future<bool> updateRedemptionStatus(String redeemId, String status) async {
    try {
      final response = await http.put(
        // API เดิม: /admin/redemptions/{redeem_id}/status?status={status}
        Uri.parse('$baseUrl/redemptions/$redeemId/status?status=$status'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error updating status: $e");
      return false;
    }
  }

  // [NEW] Reward Inventory Management
  Future<bool> createReward(String adminId, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/rewards?admin_id=$adminId'),
      headers: {"Content-Type": "application/json"},
      body: json.encode(data),
    );
    return response.statusCode == 200;
  }

  Future<bool> updateReward(
    String adminId,
    String prizeId,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/rewards/$prizeId?admin_id=$adminId'),
      headers: {"Content-Type": "application/json"},
      body: json.encode(data),
    );
    return response.statusCode == 200;
  }

  Future<bool> deleteReward(String adminId, String prizeId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/rewards/$prizeId?admin_id=$adminId'),
    );
    return response.statusCode == 200;
  }

  // [NEW] Methods for Point Policy Management
  Future<Map<String, dynamic>> getPointPolicy(String adminId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/policy/points?admin_id=$adminId'),
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('Failed to load point policy');
      }
    } catch (e) {
      print("Error fetching point policy: $e");
      // Return default structure on error to prevent UI crash
      return {
        "policy_id": null,
        "policy_name": "Default Policy",
        "start_date": DateTime.now().toIso8601String().substring(0, 10),
        "end_date": DateTime.now().toIso8601String().substring(0, 10),
        "description": "Connection Error",
      };
    }
  }

  Future<bool> updatePointPolicy(
    String adminId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/policy/points?admin_id=$adminId'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(error['detail'] ?? 'Failed to update point policy');
      }
    } catch (e) {
      print("Error updating point policy: $e");
      throw Exception(e.toString());
    }
  }

  // [ADDED] สั่งรัน Batch ตัดคะแนน
  Future<Map<String, dynamic>> triggerExpiryBatch(String adminId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/policy/run_expiry_batch?admin_id=$adminId'),
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('Failed to run expiry batch');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // [NEW] Import Employees via CSV
  Future<Map<String, dynamic>> importEmployees(
    String adminId,
    File csvFile,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/import_employees'),
      );

      request.fields['admin_id'] = adminId;

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          csvFile.path,
          contentType: MediaType('text', 'csv'),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('Import failed: ${response.body}');
      }
    } catch (e) {
      print("Import Error: $e");
      throw Exception(e.toString());
    }
  }
}
