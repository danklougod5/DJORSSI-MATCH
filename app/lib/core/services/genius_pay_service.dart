import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class GeniusPayInitResult {
  final String checkoutUrl;
  final String reference;

  GeniusPayInitResult({
    required this.checkoutUrl,
    required this.reference,
  });
}

class GeniusPayService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Initialise un paiement via l'Edge Function Supabase
  /// Retourne l'URL de checkout et la référence si succès, sinon lève une exception
  static Future<GeniusPayInitResult> initiatePayment({
    required double amount,
    required String name,
    required String email,
    required String phone,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'geniuspay-initiate',
        body: {
          'amount': amount,
          'customer': {
            'name': name,
            'email': email,
            'phone': phone,
          },
          'description': description,
          'metadata': metadata,
        },
      );

      if (response.status != 201 && response.status != 200) {
        throw Exception('Erreur lors de l\'initialisation du paiement: ${response.data}');
      }

      final data = response.data;
      if (data['success'] == true && data['data'] != null) {
        final checkoutUrl = data['data']['checkout_url'] ?? data['data']['payment_url'];
        final reference = data['data']['reference'] ?? data['data']['id']?.toString();
        if (checkoutUrl != null && reference != null) {
          return GeniusPayInitResult(
            checkoutUrl: checkoutUrl.toString(),
            reference: reference.toString(),
          );
        }
      }
      
      throw Exception('Détails du paiement non reçus');
    } catch (e) {
      debugPrint('GeniusPay Error: $e');
      rethrow;
    }
  }

  /// Ouvre l'URL de paiement dans le navigateur ou l'application externe
  static Future<void> launchCheckout(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } else {
      throw Exception('Impossible d\'ouvrir l\'URL de paiement: $url');
    }
  }
}
