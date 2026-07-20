import 'dart:async';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionService {
  static final _supabase = Supabase.instance.client;
  static bool _showPremiumBase = false;
  static bool? _userShowPremiumOverride;

  static bool get showPremium {
    if (_userShowPremiumOverride != null) {
      return _userShowPremiumOverride!;
    }
    return _showPremiumBase;
  }

  static set showPremium(bool value) {
    _showPremiumBase = value;
  }

  static final ValueNotifier<bool> showPremiumNotifier = ValueNotifier<bool>(false);
  static StreamSubscription? _subscription;
  static StreamSubscription<AuthState>? _authSubscription;

  /// Charge dynamiquement l'override show_premium depuis la table profiles
  static Future<void> updateUserOverride() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _userShowPremiumOverride = null;
        return;
      }
      final response = await _supabase
          .from('profiles')
          .select('show_premium')
          .eq('id', user.id)
          .maybeSingle();
      if (response != null && response['show_premium'] != null) {
        _userShowPremiumOverride = response['show_premium'] == true;
      } else {
        _userShowPremiumOverride = null;
      }
      showPremiumNotifier.value = showPremium;
      debugPrint('VersionService: updateUserOverride -> _userShowPremiumOverride = $_userShowPremiumOverride, showPremium = $showPremium');
    } catch (e) {
      debugPrint('VersionService: Erreur lors du chargement de show_premium override: $e');
    }
  }

  /// Écoute en temps réel les changements du champ show_premium de l'utilisateur
  static void _subscribeToProfileChanges(String userId) {
    _subscription?.cancel();
    _subscription = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((data) {
          debugPrint('VersionService [PROFILE REALTIME]: $data');
          if (data.isNotEmpty) {
            final newValue = data.first['show_premium'] == true;
            final hasOverride = data.first['show_premium'] != null;
            final newOverride = hasOverride ? newValue : null;
            
            if (_userShowPremiumOverride != newOverride) {
              _userShowPremiumOverride = newOverride;
              showPremiumNotifier.value = showPremium;
              debugPrint('VersionService [PROFILE REALTIME]: show_premium changé → $showPremium');
            }
          }
        }, onError: (err) {
          debugPrint('VersionService [PROFILE REALTIME ERROR]: $err');
        });
  }

  // --- Configuration dynamique des swipes (table app_config) ---
  static int swipeLimit = 10;
  static String swipeLimitTitle = 'Limite atteinte !';
  static String swipeLimitMessage =
      'Vous avez utilisé vos {limit} swipes gratuits pour aujourd\'hui.';
  static final ValueNotifier<int> swipeLimitNotifier = ValueNotifier<int>(10);

  // --- Période d'essai gratuite du générateur de CV ---
  static bool cvTrialActive = false;
  static DateTime? cvTrialEndDate;
  static final ValueNotifier<bool> cvTrialNotifier = ValueNotifier<bool>(false);

  // --- Période d'essai gratuite de l'adaptation IA de CV ---
  static bool aiAdaptTrialActive = true; // Actif par défaut pour le lancement
  static DateTime? aiAdaptTrialEndDate;
  static int aiAdaptFreeLimit = 10; // Limite mensuelle pour les utilisateurs gratuits après le trial
  static int aiAdaptPrice = 500; // Prix par adaptation pour les non-abonnés
  static final ValueNotifier<bool> aiAdaptTrialNotifier = ValueNotifier<bool>(true);

  // --- Tarification Premium et CV ---
  static int premiumPriceCfa = 2000;
  static int extraCvPriceCfa = 500;
  static final ValueNotifier<int> premiumPriceNotifier = ValueNotifier<int>(2000);
  static final ValueNotifier<int> extraCvPriceNotifier = ValueNotifier<int>(500);

  /// Retourne true si le trial CV est actif ET que la date de fin n'est pas dépassée.
  static bool get isCvTrialRunning {
    if (!cvTrialActive) return false;
    if (cvTrialEndDate == null) return true; // Pas de date → actif indéfiniment
    return DateTime.now().isBefore(cvTrialEndDate!);
  }

  /// Retourne true si le trial d'adaptation IA est actif ET que la date de fin n'est pas dépassée.
  static bool get isAiAdaptTrialRunning {
    if (!aiAdaptTrialActive) return false;
    if (aiAdaptTrialEndDate == null) return true; // Pas de date → actif indéfiniment
    return DateTime.now().isBefore(aiAdaptTrialEndDate!);
  }

  /// Applique la configuration du trial CV depuis une ligne app_config.
  static void _applyCvTrialConfig(Map<String, dynamic> data) {
    if (data.containsKey('cv_trial_active')) {
      cvTrialActive = data['cv_trial_active'] == true;
    }
    if (data.containsKey('cv_trial_end_date')) {
      final raw = data['cv_trial_end_date'];
      if (raw == null) {
        cvTrialEndDate = null;
      } else {
        cvTrialEndDate = DateTime.tryParse(raw.toString());
      }
    }
    cvTrialNotifier.value = isCvTrialRunning;
  }

  /// Applique la configuration du trial d'adaptation IA depuis une ligne app_config.
  static void _applyAiAdaptTrialConfig(Map<String, dynamic> data) {
    if (data.containsKey('ai_adapt_trial_active')) {
      aiAdaptTrialActive = data['ai_adapt_trial_active'] == true;
    }
    if (data.containsKey('ai_adapt_trial_end_date')) {
      final raw = data['ai_adapt_trial_end_date'];
      if (raw == null) {
        aiAdaptTrialEndDate = null;
      } else {
        aiAdaptTrialEndDate = DateTime.tryParse(raw.toString());
      }
    }
    if (data.containsKey('ai_adapt_free_limit')) {
      final rawLimit = data['ai_adapt_free_limit'];
      if (rawLimit != null) {
        final parsed = rawLimit is int ? rawLimit : int.tryParse(rawLimit.toString());
        if (parsed != null && parsed >= 0) {
          aiAdaptFreeLimit = parsed;
        }
      }
    }
    if (data.containsKey('ai_adapt_price')) {
      final rawPrice = data['ai_adapt_price'];
      if (rawPrice != null) {
        final parsed = rawPrice is int ? rawPrice : int.tryParse(rawPrice.toString());
        if (parsed != null && parsed >= 0) {
          aiAdaptPrice = parsed;
        }
      }
    }
    aiAdaptTrialNotifier.value = isAiAdaptTrialRunning;
  }

  /// Applique la configuration de tarification depuis une ligne app_config.
  static void _applyPricingConfig(Map<String, dynamic> data) {
    if (data.containsKey('premium_price_cfa')) {
      final rawPrice = data['premium_price_cfa'];
      if (rawPrice != null) {
        final parsed = rawPrice is int ? rawPrice : int.tryParse(rawPrice.toString());
        if (parsed != null && parsed >= 0) {
          premiumPriceCfa = parsed;
          premiumPriceNotifier.value = parsed;
        }
      }
    }
    if (data.containsKey('extra_cv_price_cfa')) {
      final rawPrice = data['extra_cv_price_cfa'];
      if (rawPrice != null) {
        final parsed = rawPrice is int ? rawPrice : int.tryParse(rawPrice.toString());
        if (parsed != null && parsed >= 0) {
          extraCvPriceCfa = parsed;
          extraCvPriceNotifier.value = parsed;
        }
      }
    }
  }

  /// Message de limite avec le placeholder {limit} remplacé par la valeur configurée.
  static String formattedSwipeMessage() =>
      swipeLimitMessage.replaceAll('{limit}', swipeLimit.toString());

  /// Applique la configuration des swipes provenant d'une ligne app_config.
  static void _applySwipeConfig(Map<String, dynamic> data) {
    final rawLimit = data['swipe_limit'];
    if (rawLimit != null) {
      final parsed = rawLimit is int ? rawLimit : int.tryParse(rawLimit.toString());
      if (parsed != null && parsed > 0) {
        swipeLimit = parsed;
        swipeLimitNotifier.value = parsed;
      }
    }

    final rawTitle = data['swipe_limit_title'];
    if (rawTitle is String && rawTitle.trim().isNotEmpty) {
      swipeLimitTitle = rawTitle;
    }

    final rawMessage = data['swipe_limit_message'];
    if (rawMessage is String && rawMessage.trim().isNotEmpty) {
      swipeLimitMessage = rawMessage;
    }
  }

  /// Écoute les changements en temps réel sur la table app_config et profiles
  static void listenToChanges() {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser != null) {
      _subscribeToProfileChanges(currentUser.id);
    }

    _authSubscription ??= _supabase.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      if (user != null) {
        _subscribeToProfileChanges(user.id);
      } else {
        _subscription?.cancel();
        _subscription = null;
        _userShowPremiumOverride = null;
        showPremiumNotifier.value = showPremium;
      }
      await updateUserOverride();
      debugPrint('VersionService: Changement d\'auth détecté. showPremium = $showPremium');
    });

    debugPrint('VersionService: Tentative de connexion au Realtime...');
    _supabase
        .channel('app_config_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'app_config',
          callback: (payload) {
            debugPrint('VersionService [REALTIME PAYLOAD]: ${payload.toString()}');
            final data = payload.newRecord;
            if (data == null || data.isEmpty) return;
            if (data.containsKey('show_premium')) {
              final newValue = data['show_premium'] == true;
              if (_showPremiumBase != newValue) {
                _showPremiumBase = newValue;
                showPremiumNotifier.value = showPremium;
                debugPrint('VersionService [REALTIME]: show_premium changé → $showPremium');
              }
            }
            // Synchronise la configuration des swipes en temps réel
            _applySwipeConfig(data);
            debugPrint('VersionService [REALTIME]: swipe_limit → $swipeLimit');
            // Synchronise le trial CV en temps réel
            _applyCvTrialConfig(data);
            debugPrint('VersionService [REALTIME]: cv_trial_active → $cvTrialActive');
            // Synchronise le trial adaptation IA en temps réel
            _applyAiAdaptTrialConfig(data);
            debugPrint('VersionService [REALTIME]: ai_adapt_trial_active → $aiAdaptTrialActive');
            // Synchronise la tarification en temps réel
            _applyPricingConfig(data);
            debugPrint('VersionService [REALTIME]: premiumPriceCfa → $premiumPriceCfa, extraCvPriceCfa → $extraCvPriceCfa');
          },
        )
        .subscribe((status, [error]) {
          debugPrint('VersionService [REALTIME STATUS]: $status');
          if (error != null) {
            debugPrint('VersionService [REALTIME ERROR]: $error');
          }
        });
  }

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
          .select()
          .eq('id', 1)
          .maybeSingle();

      if (response == null) {
        debugPrint('VersionService: Aucune configuration trouvée pour id=1');
        return;
      }

      debugPrint('VersionService: Config reçue: $response');
      _showPremiumBase = response['show_premium'] == true;
      await updateUserOverride(); // Charge l'override utilisateur
      _applySwipeConfig(Map<String, dynamic>.from(response));
      _applyCvTrialConfig(Map<String, dynamic>.from(response));
      _applyAiAdaptTrialConfig(Map<String, dynamic>.from(response));
      _applyPricingConfig(Map<String, dynamic>.from(response));
      debugPrint(
        'VersionService: Initialisation terminée. showPremium: $showPremium, swipeLimit: $swipeLimit, premiumPrice: $premiumPriceCfa, extraCvPrice: $extraCvPriceCfa, aiAdaptTrial: $aiAdaptTrialActive',
      );

      final minVersion = response['min_version'] as String?;
      final storeUrl = response['store_url'] as String? ?? 'https://play.google.com/store/apps/details?id=com.djossimatch.djossimatch';

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
