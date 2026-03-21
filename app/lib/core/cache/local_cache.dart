import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCache {
  static const String jobsKey = 'cached_jobs';
  static const String matchesKey = 'cached_matches';
  static const String profileKey = 'cached_profile';
  static const String skillsKey = 'cached_skills';

  static Future<void> save(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, json.encode(data));
  }

  static Future<dynamic> load(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(key);
    if (data == null) return null;
    return json.decode(data);
  }

  static Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
