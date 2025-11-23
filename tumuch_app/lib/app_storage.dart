// lib/app_storage.dart
import 'package:flutter/material.dart';

/// Base URL of your backend API

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

  // String support (for user_id)
  Future<void> setString(String key, String value) async {
    _storage[key] = value;
    debugPrint('DUMMY: setString($key = $value)');
  }

  Future<String?> getString(String key) async {
    final value = _storage[key];
    return value is String ? value : null;
  }

  static Future<DummySharedPreferences> getInstance() async {
    return DummySharedPreferences();
  }
}

/// Type alias so you can later switch to real SharedPreferences
typedef AppPrefs = DummySharedPreferences;

/// Global keys used consistently across the app
const String onboardingCompleteKey = 'onboarding_complete';
const String impactScorePrefix = 'impact_score_';
const String controlledAppsKey = 'controlled_apps';
const String userIdKey = 'user_id';

/// Helper to load the stored user_id (if any)
Future<String?> loadUserId() async {
  final prefs = await AppPrefs.getInstance();
  return await prefs.getString(userIdKey);
}

/// Helper to build default headers for API requests,
/// automatically including user_id if available.
Future<Map<String, String>> buildDefaultHeaders() async {
  final userId = await loadUserId();
  return {
    'Content-Type': 'application/json',
    if (userId != null) 'X-User-Id': userId,
  };
}

