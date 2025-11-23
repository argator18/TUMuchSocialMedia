// lib/usage_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';

class UsageService {
  static const MethodChannel _channel = MethodChannel('app.channel.route');

  static Future<List<dynamic>> getUsageSummary() async {
    try {
      final raw = await _channel.invokeMethod<String>('getUsageSummary');
      if (raw == null) return [];

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<void> openUsageSettings() async {
    try {
      await _channel.invokeMethod('openUsageAccessSettings');
    } catch (_) {}
  }

  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }
}
