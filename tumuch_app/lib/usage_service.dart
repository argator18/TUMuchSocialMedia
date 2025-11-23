// lib/usage_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'app_storage.dart';


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

  /// Daily history from native side for the *selected* apps only.
  /// Native returns JSON:
  /// [
  ///   { "date": "2025-10-01", "totalMinutes": 123 },
  ///   ...
  /// ]
  static Future<List<Map<String, dynamic>>> getDailyUsageHistory() async {
    try {
      // Load selected apps from settings (controlledAppsKey)
      final prefs = await AppPrefs.getInstance();
      final selectedApps =
          await prefs.getStringList(controlledAppsKey) ?? <String>[];

      // If you prefer "all apps" when nothing is selected, you can
      // pass null instead and treat that specially on native side.
      final raw = await _channel.invokeMethod<String>(
        'getDailyUsageHistory',
        <String, dynamic>{
          'apps': selectedApps,
        },
      );

      if (raw == null) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return [];
    }
  }
}

class _DayUsage {
  final DateTime date;
  final int minutes;
  _DayUsage(this.date, this.minutes);
}

