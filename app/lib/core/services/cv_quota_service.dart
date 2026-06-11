import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages CV creation and modification quotas based on user tier.
///
/// Rules:
/// - Free users: 1 CV creation included. Modifications cost 500 F CFA each.
/// - Premium users: 3 CV creations included. Modifications cost 500 F CFA each.
/// - Both tiers: Additional CVs beyond the limit cost 500 F CFA each.
class CvQuotaService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static const int freeMaxCvs = 1;
  static const int premiumMaxCvs = 3;
  static const double extraCvPrice = 500; // F CFA
  static const double modificationPrice = 500; // F CFA

  /// Fetch both premium status and extra CVs purchased in a single query
  static Future<UserQuotaDetails> getUserQuotaDetails() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return UserQuotaDetails(isPremium: false, extraCvsPurchased: 0);

      final response = await _supabase
          .from('profiles')
          .select('is_premium, premium_until, extra_cvs_purchased')
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) return UserQuotaDetails(isPremium: false, extraCvsPurchased: 0);

      final isPremiumVal = response['is_premium'] ?? false;
      final premiumUntilRaw = response['premium_until'];
      final extraPurchased = (response['extra_cvs_purchased'] ?? 0) as int;

      bool activePremium = isPremiumVal;
      if (isPremiumVal && premiumUntilRaw != null) {
        final premiumUntil = DateTime.parse(premiumUntilRaw);
        activePremium = premiumUntil.isAfter(DateTime.now());
      }

      return UserQuotaDetails(isPremium: activePremium, extraCvsPurchased: extraPurchased);
    } catch (e) {
      debugPrint('CvQuotaService.getUserQuotaDetails error: $e');
      return UserQuotaDetails(isPremium: false, extraCvsPurchased: 0);
    }
  }

  /// Check if the current user is premium (active subscription)
  static Future<bool> isPremium() async {
    final details = await getUserQuotaDetails();
    return details.isPremium;
  }

  /// Get the number of CVs the current user has created
  static Future<int> getCvCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;

      final response = await _supabase
          .from('user_cvs')
          .select('id')
          .eq('user_id', user.id);

      return (response as List).length;
    } catch (e) {
      debugPrint('CvQuotaService.getCvCount error: $e');
      return 0;
    }
  }

  /// Get the max allowed free CV creations for the user's tier
  static Future<int> getMaxFreeCvs() async {
    final premium = await isPremium();
    return premium ? premiumMaxCvs : freeMaxCvs;
  }

  /// Get the number of additional CVs purchased by the user
  static Future<int> getExtraCvsPurchased() async {
    final details = await getUserQuotaDetails();
    return details.extraCvsPurchased;
  }

  /// Check if the user can create a new CV (within quota)
  static Future<CvQuotaResult> canCreateCv({bool? isPremiumUser, int? extraPurchased}) async {
    bool premium;
    int extra;

    if (isPremiumUser != null && extraPurchased != null) {
      premium = isPremiumUser;
      extra = extraPurchased;
    } else {
      final details = await getUserQuotaDetails();
      premium = isPremiumUser ?? details.isPremium;
      extra = extraPurchased ?? details.extraCvsPurchased;
    }

    final cvCount = await getCvCount();
    final maxFree = premium ? premiumMaxCvs : freeMaxCvs;
    final totalAllowed = maxFree + extra;

    if (cvCount < totalAllowed) {
      return CvQuotaResult(
        allowed: true,
        currentCount: cvCount,
        maxFree: maxFree,
        extraPurchased: extra,
        isPremium: premium,
      );
    }

    return CvQuotaResult(
      allowed: false,
      currentCount: cvCount,
      maxFree: maxFree,
      extraPurchased: extra,
      isPremium: premium,
      requiresPayment: true,
      paymentAmount: extraCvPrice,
      paymentReason: PaymentReason.extraCv,
    );
  }

  /// Check if the user can modify an existing CV (free users pay, premium users modify for free)
  static Future<CvQuotaResult> canModifyCv({bool? isPremiumUser, int? extraPurchased}) async {
    bool premium;
    int extra;

    if (isPremiumUser != null && extraPurchased != null) {
      premium = isPremiumUser;
      extra = extraPurchased;
    } else {
      final details = await getUserQuotaDetails();
      premium = isPremiumUser ?? details.isPremium;
      extra = extraPurchased ?? details.extraCvsPurchased;
    }

    final cvCount = await getCvCount();
    final maxFree = premium ? premiumMaxCvs : freeMaxCvs;

    if (premium) {
      return CvQuotaResult(
        allowed: true,
        currentCount: cvCount,
        maxFree: maxFree,
        extraPurchased: extra,
        isPremium: premium,
      );
    }

    return CvQuotaResult(
      allowed: false,
      currentCount: cvCount,
      maxFree: maxFree,
      extraPurchased: extra,
      isPremium: premium,
      requiresPayment: true,
      paymentAmount: modificationPrice,
      paymentReason: PaymentReason.modification,
    );
  }

  /// Record that the user purchased an extra CV slot
  static Future<void> recordExtraCvPurchase() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Get current count
      final current = await getExtraCvsPurchased();

      await _supabase
          .from('profiles')
          .update({'extra_cvs_purchased': current + 1})
          .eq('id', user.id);

      debugPrint('CvQuotaService: Extra CV purchase recorded (${current + 1})');
    } catch (e) {
      debugPrint('CvQuotaService.recordExtraCvPurchase error: $e');
    }
  }

  /// Get quota info summary for display
  static Future<CvQuotaInfo> getQuotaInfo({bool? isPremiumUser, int? extraPurchased}) async {
    bool premium;
    int extra;

    if (isPremiumUser != null && extraPurchased != null) {
      premium = isPremiumUser;
      extra = extraPurchased;
    } else {
      final details = await getUserQuotaDetails();
      premium = isPremiumUser ?? details.isPremium;
      extra = extraPurchased ?? details.extraCvsPurchased;
    }

    final cvCount = await getCvCount();
    final maxFree = premium ? premiumMaxCvs : freeMaxCvs;

    return CvQuotaInfo(
      isPremium: premium,
      cvCount: cvCount,
      maxFreeCvs: maxFree,
      extraPurchased: extra,
      remaining: (maxFree + extra) - cvCount,
    );
  }
}

/// Result of a quota check
class CvQuotaResult {
  final bool allowed;
  final int currentCount;
  final int maxFree;
  final int extraPurchased;
  final bool isPremium;
  final bool requiresPayment;
  final double paymentAmount;
  final PaymentReason paymentReason;

  CvQuotaResult({
    required this.allowed,
    required this.currentCount,
    required this.maxFree,
    required this.extraPurchased,
    required this.isPremium,
    this.requiresPayment = false,
    this.paymentAmount = 0,
    this.paymentReason = PaymentReason.none,
  });

  int get totalAllowed => maxFree + extraPurchased;
  int get remaining => totalAllowed - currentCount;
}

/// Summary info for UI display
class CvQuotaInfo {
  final bool isPremium;
  final int cvCount;
  final int maxFreeCvs;
  final int extraPurchased;
  final int remaining;

  CvQuotaInfo({
    required this.isPremium,
    required this.cvCount,
    required this.maxFreeCvs,
    required this.extraPurchased,
    required this.remaining,
  });

  int get totalAllowed => maxFreeCvs + extraPurchased;
  String get tierLabel => isPremium ? 'Premium' : 'Gratuit';
}

enum PaymentReason {
  none,
  extraCv,
  modification,
}

class UserQuotaDetails {
  final bool isPremium;
  final int extraCvsPurchased;

  UserQuotaDetails({required this.isPremium, required this.extraCvsPurchased});
}
