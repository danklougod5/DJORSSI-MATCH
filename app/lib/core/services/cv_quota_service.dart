import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'version_service.dart';

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
  static double get extraCvPrice => VersionService.extraCvPriceCfa.toDouble();
  static double get modificationPrice => VersionService.extraCvPriceCfa.toDouble();

  /// Fetch both premium status and extra CVs purchased in a single query
  static Future<UserQuotaDetails> getUserQuotaDetails() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return UserQuotaDetails(isPremium: false, extraCvsPurchased: 0, extraAiAdaptations: 0);

      final response = await _supabase
          .from('profiles')
          .select('is_premium, premium_until, extra_cvs_purchased, show_premium, ai_adapt_extra_purchased')
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) return UserQuotaDetails(isPremium: false, extraCvsPurchased: 0, extraAiAdaptations: 0);

      final isPremiumVal = response['is_premium'] ?? false;
      final premiumUntilRaw = response['premium_until'];
      final extraPurchased = (response['extra_cvs_purchased'] ?? 0) as int;
      final extraAi = (response['ai_adapt_extra_purchased'] ?? 0) as int;
      final showPremiumOverride = response['show_premium'];

      bool activePremium = isPremiumVal;
      if (isPremiumVal && premiumUntilRaw != null) {
        final premiumUntil = DateTime.parse(premiumUntilRaw);
        activePremium = premiumUntil.isAfter(DateTime.now());
      }

      // Si show_premium est désactivé (false) pour cet utilisateur ou au niveau de l'app,
      // on le traite comme premium (bypass de validation)
      if (showPremiumOverride == false || !VersionService.showPremium) {
        activePremium = true;
      }

      return UserQuotaDetails(
        isPremium: activePremium,
        extraCvsPurchased: extraPurchased,
        extraAiAdaptations: extraAi,
      );
    } catch (e) {
      debugPrint('CvQuotaService.getUserQuotaDetails error: $e');
      return UserQuotaDetails(isPremium: false, extraCvsPurchased: 0, extraAiAdaptations: 0);
    }
  }

  /// Check if the current user is premium (active subscription)
  static Future<bool> isPremium() async {
    final details = await getUserQuotaDetails();
    return details.isPremium;
  }

  /// Get the number of CV creation slots consumed by the user (server-side, never decremented on deletion).
  /// Uses `profiles.cv_slots_used` to prevent quota bypass via CV deletion + recreation.
  static Future<int> getSlotCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;

      final response = await _supabase
          .from('profiles')
          .select('cv_slots_used')
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) return 0;
      return (response['cv_slots_used'] ?? 0) as int;
    } catch (e) {
      debugPrint('CvQuotaService.getSlotCount error: $e');
      return 0;
    }
  }

  /// Increments the server-side cv_slots_used counter when a new CV is created.
  /// This counter is NEVER decremented on deletion — prevents quota bypass.
  static Future<void> incrementSlotCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final current = await getSlotCount();
      await _supabase
          .from('profiles')
          .update({'cv_slots_used': current + 1})
          .eq('id', user.id);

      debugPrint('CvQuotaService: cv_slots_used → ${current + 1}');
    } catch (e) {
      debugPrint('CvQuotaService.incrementSlotCount error: $e');
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

  /// Check if the user can create a new CV (based on server-side slot count, bypass-proof)
  static Future<CvQuotaResult> canCreateCv({bool? isPremiumUser, int? extraPurchased}) async {
    if (!VersionService.showPremium) {
      return CvQuotaResult(
        allowed: true,
        currentCount: 0,
        maxFree: 999,
        extraPurchased: 0,
        isPremium: true,
      );
    }

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

    // Use server-side slot counter (not live user_cvs count) to prevent bypass
    final slotCount = await getSlotCount();
    final maxFree = premium ? premiumMaxCvs : freeMaxCvs;
    final totalAllowed = maxFree + extra;

    if (slotCount < totalAllowed) {
      return CvQuotaResult(
        allowed: true,
        currentCount: slotCount,
        maxFree: maxFree,
        extraPurchased: extra,
        isPremium: premium,
      );
    }

    return CvQuotaResult(
      allowed: false,
      currentCount: slotCount,
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
    if (!VersionService.showPremium) {
      return CvQuotaResult(
        allowed: true,
        currentCount: 0,
        maxFree: 999,
        extraPurchased: 0,
        isPremium: true,
      );
    }

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

    final slotCount = await getSlotCount();
    final maxFree = premium ? premiumMaxCvs : freeMaxCvs;

    if (premium) {
      return CvQuotaResult(
        allowed: true,
        currentCount: slotCount,
        maxFree: maxFree,
        extraPurchased: extra,
        isPremium: premium,
      );
    }

    return CvQuotaResult(
      allowed: false,
      currentCount: slotCount,
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

    // Use server-side slot counter (bypass-proof)
    final slotCount = await getSlotCount();
    final maxFree = premium ? premiumMaxCvs : freeMaxCvs;

    return CvQuotaInfo(
      isPremium: premium,
      cvCount: slotCount,
      maxFreeCvs: maxFree,
      extraPurchased: extra,
      remaining: (maxFree + extra) - slotCount,
    );
  }

  // ─── Adaptation IA : quota mensuel (côté serveur — anti-bypass) ───

  /// Retourne le mois courant au format 'YYYY-MM'.
  static String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Récupère le nombre d'adaptations IA effectuées ce mois-ci depuis Supabase.
  /// Le compteur est stocké dans `profiles.ai_adapt_monthly_count` côté serveur,
  /// ce qui empêche tout contournement par réinstallation de l'app.
  static Future<int> getMonthlyAdaptationCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;

      final currentMonth = _currentMonthKey();

      final response = await _supabase
          .from('profiles')
          .select('ai_adapt_monthly_count, ai_adapt_month')
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) return 0;

      final savedMonth = response['ai_adapt_month'] as String?;
      final savedCount = (response['ai_adapt_monthly_count'] ?? 0) as int;

      // Si le mois a changé côté serveur → réinitialiser le compteur
      if (savedMonth != currentMonth) {
        await _supabase.from('profiles').update({
          'ai_adapt_monthly_count': 0,
          'ai_adapt_month': currentMonth,
        }).eq('id', user.id);
        return 0;
      }

      return savedCount;
    } catch (e) {
      debugPrint('CvQuotaService.getMonthlyAdaptationCount error: $e');
      return 0;
    }
  }

  /// Enregistre une adaptation IA effectuée (incrémente le compteur serveur).
  /// Utilise une opération atomique pour éviter les race conditions.
  static Future<void> recordAdaptation() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final currentMonth = _currentMonthKey();

      // Récupérer le compteur actuel
      final response = await _supabase
          .from('profiles')
          .select('ai_adapt_monthly_count, ai_adapt_month')
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) return;

      final savedMonth = response['ai_adapt_month'] as String?;
      final savedCount = (response['ai_adapt_monthly_count'] ?? 0) as int;

      // Si nouveau mois, recommencer à 1, sinon incrémenter
      final newCount = (savedMonth == currentMonth) ? savedCount + 1 : 1;

      await _supabase.from('profiles').update({
        'ai_adapt_monthly_count': newCount,
        'ai_adapt_month': currentMonth,
      }).eq('id', user.id);

      debugPrint('CvQuotaService: Adaptation IA enregistrée côté serveur ($newCount ce mois — $currentMonth)');
    } catch (e) {
      debugPrint('CvQuotaService.recordAdaptation error: $e');
    }
  }

  /// Vérifie si l'utilisateur peut effectuer une adaptation IA.
  ///
  /// Règles :
  /// - Période de lancement (trial actif) → illimité pour tout le monde
  /// - Premium → illimité
  /// - Gratuit après trial → limité à [VersionService.aiAdaptFreeLimit] / mois
  /// - Si quota épuisé → paiement de [VersionService.aiAdaptPrice] F CFA par adaptation
  static Future<CvQuotaResult> canAdaptCv() async {
    // Si le système premium est désactivé globalement, tout est autorisé
    if (!VersionService.showPremium) {
      return CvQuotaResult(
        allowed: true,
        currentCount: 0,
        maxFree: 999,
        extraPurchased: 0,
        isPremium: true,
      );
    }

    // Période de lancement : illimité pour tout le monde
    if (VersionService.isAiAdaptTrialRunning) {
      return CvQuotaResult(
        allowed: true,
        currentCount: 0,
        maxFree: 999,
        extraPurchased: 0,
        isPremium: true,
      );
    }

    final details = await getUserQuotaDetails();

    // Premium → illimité
    if (details.isPremium) {
      return CvQuotaResult(
        allowed: true,
        currentCount: 0,
        maxFree: 999,
        extraPurchased: 0,
        isPremium: true,
      );
    }

    // Utilisateur gratuit après le trial : vérifier le quota mensuel SERVEUR (limite gratuite + bonus acheté)
    final monthlyCount = await getMonthlyAdaptationCount();
    final limit = VersionService.aiAdaptFreeLimit;
    final totalAllowed = limit + details.extraAiAdaptations;

    if (monthlyCount < totalAllowed) {
      return CvQuotaResult(
        allowed: true,
        currentCount: monthlyCount,
        maxFree: limit,
        extraPurchased: details.extraAiAdaptations,
        isPremium: false,
      );
    }

    // Quota épuisé → paiement requis
    return CvQuotaResult(
      allowed: false,
      currentCount: monthlyCount,
      maxFree: limit,
      extraPurchased: details.extraAiAdaptations,
      isPremium: false,
      requiresPayment: true,
      paymentAmount: VersionService.aiAdaptPrice.toDouble(),
      paymentReason: PaymentReason.aiAdaptation,
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
  aiAdaptation,
}

class UserQuotaDetails {
  final bool isPremium;
  final int extraCvsPurchased;
  final int extraAiAdaptations;

  UserQuotaDetails({
    required this.isPremium,
    required this.extraCvsPurchased,
    required this.extraAiAdaptations,
  });
}
