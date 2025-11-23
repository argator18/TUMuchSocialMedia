import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'context_logger.dart';
import 'app_configs.dart';

import 'package:http/http.dart' as http;

// IMPORTANT: import app_storage.dart:
import 'package:tumuch_app/app_storage.dart';
// or, if you’re using relative imports:
// import '../app_storage.dart';

class ScreenCaptureService {
  static const MethodChannel _channel = MethodChannel('app.channel.route');

  /// Captures the screen ONCE via native Android and sends
  /// screenshot + recent events to the backend.
  static Future<void> captureAndSend() async {
    try {
      // 1) Ask native side to capture screen once
      final Uint8List? pngBytes =
          await _channel.invokeMethod<Uint8List>('captureScreenOnce');

      if (pngBytes == null) {
        print('Screen capture returned null bytes.');
        return;
      }

      final screenshotBase64 = base64Encode(pngBytes);

      // 2) Get context events (if you added ContextLogger)
      final events = ContextLogger().getCurrentContext();
      final payload = {
        'text': events.map((e) => e.toJson()).toList(),
        'image': screenshotBase64,
      };

      final uri = Uri.parse('$API_BASE/supervise');
      final headers = await buildDefaultHeaders();
      final resp = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(payload),
      );

      print('Screen/supervise upload status: ${resp.statusCode}');
    } on PlatformException catch (e) {
      print('Screen capture error: ${e.code} ${e.message}');
    } catch (e) {
      print('Screen capture error: $e');
    }
  }
}

