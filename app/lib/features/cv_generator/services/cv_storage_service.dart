import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cv_model.dart';

class CvStorageService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _table = 'user_cvs';

  /// Save a CV (insert if new, update if existing)
  static Future<CvModel> saveCv(CvModel cv) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    final data = {
      'user_id': user.id,
      'title': cv.displayTitle,
      'cv_data': cv.toJson(),
      'template_id': cv.templateId,
      'primary_color': cv.primaryColor,
      'secondary_color': cv.secondaryColor,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (cv.id != null) {
      // Update existing
      await _supabase
          .from(_table)
          .update(data)
          .eq('id', cv.id!)
          .eq('user_id', user.id);
      return cv;
    } else {
      // Insert new
      final response = await _supabase
          .from(_table)
          .insert(data)
          .select('id')
          .single();
      return cv.copyWith(id: response['id'] as String);
    }
  }

  /// Load all CVs for the current user
  static Future<List<CvModel>> loadUserCvs() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from(_table)
        .select()
        .eq('user_id', user.id)
        .order('updated_at', ascending: false);

    return (response as List).map((row) {
      return CvModel.fromJson(
        row['cv_data'] as Map<String, dynamic>,
        id: row['id'] as String,
        title: (row['title'] ?? 'Mon CV').toString(),
        templateId: (row['template_id'] ?? 'classic').toString(),
        primaryColor: (row['primary_color'] ?? '#1E3A8A').toString(),
        secondaryColor: (row['secondary_color'] ?? '#4B5563').toString(),
      );
    }).toList();
  }

  /// Load a single CV by ID
  static Future<CvModel?> getCv(String id) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final row = await _supabase
          .from(_table)
          .select()
          .eq('id', id)
          .eq('user_id', user.id)
          .single();

      return CvModel.fromJson(
        row['cv_data'] as Map<String, dynamic>,
        id: row['id'] as String,
        title: (row['title'] ?? 'Mon CV').toString(),
        templateId: (row['template_id'] ?? 'classic').toString(),
        primaryColor: (row['primary_color'] ?? '#1E3A8A').toString(),
        secondaryColor: (row['secondary_color'] ?? '#4B5563').toString(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Delete a CV
  static Future<void> deleteCv(String id) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from(_table)
        .delete()
        .eq('id', id)
        .eq('user_id', user.id);
  }

  /// Duplicate a CV
  static Future<CvModel> duplicateCv(CvModel cv) async {
    final copy = cv.copyWith(
      id: null,
      title: '${cv.displayTitle} (copie)',
    );
    return saveCv(copy);
  }
}
