// lib/usage_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';

class UsageService {
  static const MethodChannel _channel = MethodChannel('app.channel.route');

  /// Ask native side for last 24h usage summary.
  /// Native (Kotlin) returns a JSON string (array).
  /// We decode it into a List<dynamic>.
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
      // If anything fails, just return an empty list.
      return [];
    }
  }

  /// Optional: open Android usage access settings
  static Future<void> openUsageSettings() async {
    try {
      await _channel.invokeMethod('openUsageAccessSettings');
    } catch (_) {}
  }
}
