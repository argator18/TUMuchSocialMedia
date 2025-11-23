// app_storage.dart
import 'package:flutter/material.dart';

/// Dummy in-memory SharedPreferences replacement.
/// All data is stored in a static Map and lives as long as
/// the app process is running. Perfect for development / prototyping.
/// Later you can replace this with the real `shared_preferences` package.
class DummySharedPreferences {
  static final Map<String, dynamic> _storage = {};

  Future<void> setBool(String key, bool value) async {
    _storage[key] = value;
    debugPrint('DUMMY: setBool($key = $value)');
  }

  Future<void> setDouble(String key, double value) async {
    _storage[key] = value;
    debugPrint('DUMMY: setDouble($key = $value)');
  }

  Future<void> setStringList(String key, List<String> value) async {
    _storage[key] = value;
    debugPrint('DUMMY: setStringList($key = $value)');
  }

  Future<bool?> getBool(String key) async {
    final value = _storage[key];
    return value is bool ? value : null;
  }

  Future<double?> getDouble(String key) async {
    final value = _storage[key];
    return value is double ? value : null;
  }

  Future<List<String>?> getStringList(String key) async {
    final value = _storage[key];
    return value is List ? List<String>.from(value) : null;
  }

  static Future<DummySharedPreferences> getInstance() async {
    return DummySharedPreferences();
  }
}

/// Type alias so you can later switch to real SharedPreferences
/// by changing only this typedef and the implementation above.
typedef AppPrefs = DummySharedPreferences;

/// Global keys used consistently across the app
const String onboardingCompleteKey = 'onboarding_complete';
const String impactScorePrefix = 'impact_score_';
const String controlledAppsKey = 'controlled_apps';

