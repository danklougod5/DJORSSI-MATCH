import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCache {
  static const String jobsKey = 'cached_jobs';
  static const String matchesKey = 'cached_matches';
  static const String profileKey = 'cached_profile';
  static const String skillsKey = 'cached_skills';
  static const String notificationsKey = 'cached_notifications';
  static const String swipedIdsKey = 'cached_swiped_ids';
  static const String swipeCountKey = 'cached_swipe_count';
  static const String swipeCountDateKey = 'cached_swipe_count_date';
  static const String tagsKey = 'cached_sector_tags';
  static const String chatsKey = 'cached_chats';

  // TTL defaults (in seconds)
  static const int jobsTTL = 300;          // 5 minutes
  static const int profileTTL = 120;       // 2 minutes
  static const int matchesTTL = 180;       // 3 minutes
  static const int chatsTTL = 180;         // 3 minutes
  static const int skillsTTL = 600;        // 10 minutes
  static const int notificationsTTL = 300; // 5 minutes
  static const int swipedIdsTTL = 3600;    // 1 heure (les swipes ne changent jamais)
  static const int tagsTTL = 1800;         // 30 minutes (les tags évoluent rarement)

  /// Save data with a timestamp for TTL tracking
  static Future<void> save(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, json.encode(data));
    await prefs.setInt('_ts_$key', DateTime.now().millisecondsSinceEpoch);
  }

  /// Load data regardless of age (backward compatible)
  static Future<dynamic> load(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(key);
    if (data == null) return null;
    return json.decode(data);
  }

  /// Load data only if it's fresher than [maxAgeSeconds].
  /// Returns null if the cache is stale or missing.
  static Future<dynamic> loadIfFresh(String key, int maxAgeSeconds) async {
    final prefs = await SharedPreferences.getInstance();
    final int? timestamp = prefs.getInt('_ts_$key');
    if (timestamp == null) return null;

    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age > maxAgeSeconds * 1000) return null; // Cache is stale

    final String? data = prefs.getString(key);
    if (data == null) return null;
    return json.decode(data);
  }

  /// Check if the cache for a given key is still fresh
  static Future<bool> isFresh(String key, int maxAgeSeconds) async {
    final prefs = await SharedPreferences.getInstance();
    final int? timestamp = prefs.getInt('_ts_$key');
    if (timestamp == null) return false;

    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    return age <= maxAgeSeconds * 1000;
  }

  static Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    await prefs.remove('_ts_$key');
  }

  /// Clear all cached data (useful on logout)
  static Future<void> clearAll() async {
    await clear(jobsKey);
    await clear(matchesKey);
    await clear(chatsKey);
    await clear(profileKey);
    await clear(skillsKey);
    await clear(notificationsKey);
    await clear(swipedIdsKey);
    await clear(swipeCountKey);
    await clear(swipeCountDateKey);
    await clear(tagsKey);
  }
}
