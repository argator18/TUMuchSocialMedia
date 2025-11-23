import 'dart:convert';
import 'package:flutter/services.dart';

class UsageService {
  static const MethodChannel _channel = MethodChannel('app.channel.route');

  /// Ask native side for last 24h usage summary.
  /// Native (Kotlin) returns a JSON string array:
  /// [
  ///   { "packageName": "...", "totalTimeForeground": <ms>, "lastTimeUsed": <ms> },
  ///   ...
  /// ]
  ///
  /// We:
  ///  - parse it
  ///  - convert ms -> minutes (rounded)
  ///  - drop entries with 0 minutes
  ///  - add a `totalMinutes` field for the UI
  static Future<List<dynamic>> getUsageSummary() async {
    try {
      final raw = await _channel.invokeMethod<String>('getUsageSummary');
      if (raw == null) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      final List<Map<String, dynamic>> result = [];

      for (final entry in decoded) {
        if (entry is! Map) continue;

        final ms = entry['totalTimeForeground'];
        if (ms is! num) continue;

        final minutes = (ms / 60000).round(); // ms -> minutes

        // 🔥 filter: only keep entries with > 0 minutes
        if (minutes <= 0) continue;

        // copy with String keys + add totalMinutes
        final map = <String, dynamic>{};
        entry.forEach((key, value) {
          map[key.toString()] = value;
        });
        map['totalMinutes'] = minutes;

        result.add(map);
      }

      return result;
    } catch (e) {
      return [];
    }
  }

  /// Open Android usage access settings
  static Future<void> openUsageSettings() async {
    try {
      await _channel.invokeMethod('openUsageAccessSettings');
    } catch (_) {}
  }

  /// Open Android accessibility settings to enable the accessibility service
  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }
}
