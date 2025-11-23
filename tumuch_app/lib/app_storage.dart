// lib/app_storage.dart
import 'package:shared_preferences/shared_preferences.dart';

/// Type alias so the rest of your code can keep using `AppPrefs`.
typedef AppPrefs = SharedPreferences;

/// Global keys used consistently across the app
const String onboardingCompleteKey = 'onboarding_complete';
const String impactScorePrefix = 'impact_score_';
const String controlledAppsKey = 'controlled_apps';
const String userIdKey = 'user_id';

/// Helper to load the stored user_id (if any)
Future<String?> loadUserId() async {
  final prefs = await AppPrefs.getInstance();
  final id = prefs.getString(userIdKey);
  return id;
}

/// Helper to build default headers for API requests,
/// automatically including user_id if available.
Future<Map<String, String>> buildDefaultHeaders() async {
  final prefs = await AppPrefs.getInstance();
  final userId = prefs.getString(userIdKey);

  return {
    'Content-Type': 'application/json',
    if (userId != null) 'X-User-Id': userId,
  };
}

