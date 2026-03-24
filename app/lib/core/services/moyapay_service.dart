import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';

class MoyaPayResponse {
  final int status;
  final String? paymentUrl;
  final String? payToken;
  final String? message;

  MoyaPayResponse({
    required this.status,
    this.paymentUrl,
    this.payToken,
    this.message,
  });

  factory MoyaPayResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return MoyaPayResponse(
      status: json['status'] ?? 0,
      paymentUrl: data?['payment_url'] as String?,
      payToken: data?['pay_token'] as String?,
      message: json['message'] as String?,
    );
  }
}

class MoyaPayService {
  static final String _baseUrl = 'https://services.moya-pay.com/v1';
  static final String _apiKey = dotenv.env['MOYAPAY_API_KEY'] ?? '';

  static Future<MoyaPayResponse?> initiateWavePayment({
    required double amount,
    required String phoneNumber,
    required String email,
    required String firstName,
    required String lastName,
    required String notifyUrl,
  }) async {
    try {
      if (_apiKey.isEmpty) {
        throw Exception('MoyaPay API Key not found in .env');
      }

      final url = Uri.parse('$_baseUrl/payments');
      final idempotencyKey = const Uuid().v4();

      final body = jsonEncode({
        'amount': amount.toInt(),
        'currency': 'XOF',
        'gateway': 'WAVE_CI',
        'telephone': phoneNumber,
        'metadata': {
          'recipientEmail': email,
          'recipientFirstName': firstName,
          'recipientLastName': lastName,
        },
        'notify_url': notifyUrl,
        'description': 'Abonnement Djorssi Premium',
        'success_url': 'https://djorssi-match.com/payment/success',
        'failed_url': 'https://djorssi-match.com/payment/failed',
      });

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': _apiKey,
          'Idempotency-Key': idempotencyKey,
        },
        body: body,
      );

      debugPrint('MoyaPay Response Code: ${response.statusCode}');
      debugPrint('MoyaPay Response Content: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return MoyaPayResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to initiate payment: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error initiating MoyaPay payment: $e');
      rethrow;
    }
  }
}
