import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_application_activity_record/backend_api/config.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  void connect(String empId) {
    // ถ้ามี connection อยู่แล้ว ให้ปิดก่อนเพื่อเริ่มใหม่ให้สะอาด
    if (_channel != null) {
      _channel!.sink.close();
    }

    try {
      // [FIXED] Logic แปลง URL ให้รองรับทั้ง http/https และตัด trailing slash
      String baseUrl = Config.apiUrl;
      if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }

      // บังคับเปลี่ยน http -> ws และ https -> wss
      if (baseUrl.startsWith("https://")) {
        baseUrl = baseUrl.replaceFirst("https://", "wss://");
      } else if (baseUrl.startsWith("http://")) {
        baseUrl = baseUrl.replaceFirst("http://", "ws://");
      }

      final wsUrl = Uri.parse('$baseUrl/ws?emp_id=$empId');
      print("🔌 WS Connecting to: $wsUrl"); // Debug ดู URL จริง

      _channel = WebSocketChannel.connect(wsUrl);

      _channel!.stream.listen(
        (message) {
          print("📩 WS Received: $message"); // เช็คว่าข้อความเข้าไหม
          _handleMessage(message);
        },
        onError: (error) {
          print("❌ WS Error: $error");
          _disconnect();
        },
        onDone: () {
          print("🔌 WS Disconnected");
          _disconnect();
        },
      );
    } catch (e) {
      print("❌ WS Connection Exception: $e");
    }
  }

  void _handleMessage(dynamic message) {
    final String msg = message.toString();
    if (msg.contains("|")) {
      final parts = msg.split("|");
      if (parts.isNotEmpty) {
        _eventController.add({"event": parts[0], "data": parts.sublist(1)});
      }
    } else {
      _eventController.add({"event": msg, "data": null});
    }
  }

  void _disconnect() {
    _channel = null;
  }
}
