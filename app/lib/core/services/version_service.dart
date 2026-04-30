import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionService {
  static final _supabase = Supabase.instance.client;

  /// Vérifie si une mise à jour est requise et affiche un dialogue bloquant si c'est le cas.
  static Future<void> checkVersion(BuildContext context) async {
    try {
      // 1. Récupérer la version actuelle de l'application
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      // 2. Récupérer la version minimale requise depuis Supabase
      // Table suggérée : 'app_config' avec une ligne id=1
      final response = await _supabase
          .from('app_config')
          .select('min_version, store_url')
          .eq('id', 1)
          .maybeSingle();

      if (response == null) return;

      final minVersion = response['min_version'] as String?;
      final storeUrl = response['store_url'] as String? ?? 'https://play.google.com/store/apps/details?id=com.djorssi.match';

      if (minVersion != null && _isVersionLower(currentVersion, minVersion)) {
        if (context.mounted) {
          _showUpdateDialog(context, storeUrl);
        }
      }
    } catch (e) {
      debugPrint('Erreur lors de la vérification de la version: $e');
    }
  }

  /// Compare deux versions (ex: "1.0.1" et "1.0.2")
  static bool _isVersionLower(String current, String required) {
    try {
      List<int> currentParts = current.split('.').map(int.parse).toList();
      List<int> requiredParts = required.split('.').map(int.parse).toList();

      for (int i = 0; i < requiredParts.length; i++) {
        if (i >= currentParts.length) return true;
        if (currentParts[i] < requiredParts[i]) return true;
        if (currentParts[i] > requiredParts[i]) return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static void _showUpdateDialog(BuildContext context, String storeUrl) {
    showDialog(
      context: context,
      barrierDismissible: false, // Bloquant
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Empêche le retour arrière
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.system_update, color: Color(0xFFF97316)),
              SizedBox(width: 10),
              Text('Mise à jour requise'),
            ],
          ),
          content: const Text(
            'Une nouvelle version importante de Djorssi-Match est disponible. Veuillez mettre à jour l\'application pour continuer.',
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final url = Uri.parse(storeUrl);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('METTRE À JOUR MAINTENANT', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
