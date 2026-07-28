import 'dart:async';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:djossimatch/core/routing/app_router.dart';

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

  static final ValueNotifier<bool> showPremiumNotifier = ValueNotifier<bool>(
    false,
  );
  static StreamSubscription? _subscription;
  static StreamSubscription<AuthState>? _authSubscription;

  // --- Configuration Version & Maintenance ---
  static bool appStopped = false;
  static bool forceUpdateEnabled = false;
  static String maintenanceTitle = 'Application en maintenance 🛠️';
  static String maintenanceMessage =
      'L\'application est temporairement suspendue pour maintenance. Veuillez réessayer ultérieurement.';
  static String minVersion = '1.0.0';
  static String storeUrl =
      'https://play.google.com/store/apps/details?id=com.djossimatch.djossimatch';
  static bool isDialogShowing = false;

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
      debugPrint(
        'VersionService: updateUserOverride -> _userShowPremiumOverride = $_userShowPremiumOverride, showPremium = $showPremium',
      );
    } catch (e) {
      debugPrint(
        'VersionService: Erreur lors du chargement de show_premium override: $e',
      );
    }
  }

  /// Écoute en temps réel les changements du champ show_premium de l'utilisateur
  static void _subscribeToProfileChanges(String userId) {
    _subscription?.cancel();
    _subscription = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen(
          (data) {
            debugPrint('VersionService [PROFILE REALTIME]: $data');
            if (data.isNotEmpty) {
              final newValue = data.first['show_premium'] == true;
              final hasOverride = data.first['show_premium'] != null;
              final newOverride = hasOverride ? newValue : null;

              if (_userShowPremiumOverride != newOverride) {
                _userShowPremiumOverride = newOverride;
                showPremiumNotifier.value = showPremium;
                debugPrint(
                  'VersionService [PROFILE REALTIME]: show_premium changé → $showPremium',
                );
              }
            }
          },
          onError: (err) {
            debugPrint('VersionService [PROFILE REALTIME ERROR]: $err');
          },
        );
  }

  // --- Configuration dynamique des swipes (table app_config) ---
  static int swipeLimit = 10;
  static String swipeLimitTitle = 'Limite atteinte !';
  static String swipeLimitMessage =
      'Vous avez utilisé vos {limit} swipes gratuits pour aujourd\'hui.';
  static final ValueNotifier<int> swipeLimitNotifier = ValueNotifier<int>(10);

  // --- Toggles des avantages Premium (contrôlés depuis le Dashboard Admin) ---
  static bool featUnlimitedSwipes = true;
  static bool featUnlockedHistory = true;
  static bool featCertifiedBadge = true;
  static bool featRewind = true;
  static bool featEmailAlerts = true;
  static bool featExtraCvs = true;
  static bool featAiAdaptation = true;

  // --- Période d'essai gratuite du générateur de CV ---
  static bool cvTrialActive = false;
  static DateTime? cvTrialEndDate;
  static final ValueNotifier<bool> cvTrialNotifier = ValueNotifier<bool>(false);

  // --- Période d'essai gratuite de l'adaptation IA de CV ---
  static bool aiAdaptEnabled = false;
  static bool aiAdaptTrialActive = false;
  static DateTime? aiAdaptTrialEndDate;
  static int aiAdaptFreeLimit =
      10; // Limite mensuelle pour les utilisateurs gratuits après le trial
  static int aiAdaptPrice = 500; // Prix par adaptation pour les non-abonnés
  static int aiAdaptPremiumLimit = 5; // Quota mensuel d'adaptations IA incluses en Premium (Défaut : 5)
  static final ValueNotifier<bool> aiAdaptEnabledNotifier = ValueNotifier<bool>(
    false,
  );
  static final ValueNotifier<bool> aiAdaptTrialNotifier = ValueNotifier<bool>(
    false,
  );

  // --- Tarification Premium et CV ---
  static int premiumPriceCfa = 2000;
  static int extraCvPriceCfa = 500;
  static final ValueNotifier<int> premiumPriceNotifier = ValueNotifier<int>(
    2000,
  );
  static final ValueNotifier<int> extraCvPriceNotifier = ValueNotifier<int>(
    500,
  );

  /// Retourne true si le trial CV est actif ET que la date de fin n'est pas dépassée.
  static bool get isCvTrialRunning {
    if (!cvTrialActive) return false;
    if (cvTrialEndDate == null) return true; // Pas de date → actif indéfiniment
    return DateTime.now().isBefore(cvTrialEndDate!);
  }

  /// Retourne true si le trial d'adaptation IA est actif ET que la date de fin n'est pas dépassée.
  static bool get isAiAdaptTrialRunning {
    if (!aiAdaptTrialActive) return false;
    if (aiAdaptTrialEndDate == null) {
      return true; // Pas de date → actif indéfiniment
    }
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
    if (data.containsKey('ai_adapt_enabled')) {
      aiAdaptEnabled = data['ai_adapt_enabled'] == true;
      aiAdaptEnabledNotifier.value = aiAdaptEnabled;
    }
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
        final parsed = rawLimit is int
            ? rawLimit
            : int.tryParse(rawLimit.toString());
        if (parsed != null && parsed >= 0) {
          aiAdaptFreeLimit = parsed;
        }
      }
    }
    if (data.containsKey('ai_adapt_price')) {
      final rawPrice = data['ai_adapt_price'];
      if (rawPrice != null) {
        final parsed = rawPrice is int
            ? rawPrice
            : int.tryParse(rawPrice.toString());
        if (parsed != null && parsed >= 0) {
          aiAdaptPrice = parsed;
        }
      }
    }
    if (data.containsKey('ai_adapt_premium_limit')) {
      final rawPremLimit = data['ai_adapt_premium_limit'];
      if (rawPremLimit != null) {
        final parsed = rawPremLimit is int
            ? rawPremLimit
            : int.tryParse(rawPremLimit.toString());
        if (parsed != null && parsed >= 0) {
          aiAdaptPremiumLimit = parsed;
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
        final parsed = rawPrice is int
            ? rawPrice
            : int.tryParse(rawPrice.toString());
        if (parsed != null && parsed >= 0) {
          premiumPriceCfa = parsed;
          premiumPriceNotifier.value = parsed;
        }
      }
    }
    if (data.containsKey('extra_cv_price_cfa')) {
      final rawPrice = data['extra_cv_price_cfa'];
      if (rawPrice != null) {
        final parsed = rawPrice is int
            ? rawPrice
            : int.tryParse(rawPrice.toString());
        if (parsed != null && parsed >= 0) {
          extraCvPriceCfa = parsed;
          extraCvPriceNotifier.value = parsed;
        }
      }
    }
  }

  /// Applique les toggles des avantages Premium depuis app_config.
  static void _applyPremiumFeatureToggles(Map<String, dynamic> data) {
    if (data.containsKey('feat_unlimited_swipes')) {
      featUnlimitedSwipes = data['feat_unlimited_swipes'] == true;
    }
    if (data.containsKey('feat_unlocked_history')) {
      featUnlockedHistory = data['feat_unlocked_history'] == true;
    }
    if (data.containsKey('feat_certified_badge')) {
      featCertifiedBadge = data['feat_certified_badge'] == true;
    }
    if (data.containsKey('feat_rewind')) {
      featRewind = data['feat_rewind'] == true;
    }
    if (data.containsKey('feat_email_alerts')) {
      featEmailAlerts = data['feat_email_alerts'] == true;
    }
    if (data.containsKey('feat_extra_cvs')) {
      featExtraCvs = data['feat_extra_cvs'] == true;
    }
    if (data.containsKey('feat_ai_adaptation')) {
      featAiAdaptation = data['feat_ai_adaptation'] == true;
    }
  }

  /// Applique la configuration de version et de maintenance depuis app_config.
  static void _applyVersionAndMaintenanceConfig(Map<String, dynamic> data) {
    if (data.containsKey('app_stopped')) {
      appStopped = data['app_stopped'] == true;
    } else if (data.containsKey('is_maintenance')) {
      appStopped = data['is_maintenance'] == true;
    }

    if (data.containsKey('force_update_enabled')) {
      forceUpdateEnabled = data['force_update_enabled'] == true;
    }

    if (data.containsKey('maintenance_title') &&
        data['maintenance_title'] != null) {
      final title = data['maintenance_title'].toString().trim();
      if (title.isNotEmpty) maintenanceTitle = title;
    }

    if (data.containsKey('maintenance_message') &&
        data['maintenance_message'] != null) {
      final msg = data['maintenance_message'].toString().trim();
      if (msg.isNotEmpty) maintenanceMessage = msg;
    }

    if (data.containsKey('min_version') && data['min_version'] != null) {
      final version = data['min_version'].toString().trim();
      if (version.isNotEmpty) minVersion = version;
    }

    if (data.containsKey('store_url') && data['store_url'] != null) {
      final url = data['store_url'].toString().trim();
      if (url.isNotEmpty) storeUrl = url;
    }
  }

  /// Message de limite avec le placeholder {limit} remplacé par la valeur configurée.
  static String formattedSwipeMessage() =>
      swipeLimitMessage.replaceAll('{limit}', swipeLimit.toString());

  /// Applique la configuration des swipes provenant d'une ligne app_config.
  static void _applySwipeConfig(Map<String, dynamic> data) {
    final rawLimit = data['swipe_limit'];
    if (rawLimit != null) {
      final parsed = rawLimit is int
          ? rawLimit
          : int.tryParse(rawLimit.toString());
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

  static BuildContext? activeDialogContext;

  /// Ferme la modale bloquante si elle est actuellement affichée sur l'écran.
  static void dismissDialogIfOpen() {
    if (isDialogShowing) {
      if (activeDialogContext != null && activeDialogContext!.mounted) {
        try {
          Navigator.of(activeDialogContext!).pop();
        } catch (e) {
          debugPrint('Error popping dialog with activeContext: $e');
        }
      } else {
        final navContext = AppRouter.navigatorKey.currentContext;
        if (navContext != null && navContext.mounted) {
          try {
            Navigator.of(navContext, rootNavigator: true).pop();
          } catch (e) {
            debugPrint('Error popping dialog with navContext: $e');
          }
        }
      }
      isDialogShowing = false;
      activeDialogContext = null;
    }
  }

  /// Évalue l'état actuel (arrêt/maintenance ou mise à jour requise) et affiche la modale bloquante si nécessaire.
  static Future<void> evaluateStatus(BuildContext context) async {
    if (!context.mounted) return;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final bool shouldShowMaintenance = appStopped;
      final bool shouldShowUpdate =
          forceUpdateEnabled && _isVersionLower(currentVersion, minVersion);

      debugPrint(
        'VersionService: EvaluateStatus -> current: $currentVersion, min: $minVersion, appStopped: $appStopped, forceUpdateEnabled: $forceUpdateEnabled, showing: $isDialogShowing',
      );

      if (shouldShowMaintenance) {
        if (!isDialogShowing) {
          isDialogShowing = true;
          _showMaintenanceDialog(context);
        }
      } else if (shouldShowUpdate) {
        if (!isDialogShowing) {
          isDialogShowing = true;
          _showUpdateDialog(context, storeUrl);
        }
      } else {
        // Ni la maintenance ni la mise à jour requise ne sont actives -> Fermer le dialogue si ouvert
        dismissDialogIfOpen();
      }
    } catch (e) {
      debugPrint('Error evaluating version status: $e');
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
      debugPrint(
        'VersionService: Changement d\'auth détecté. showPremium = $showPremium',
      );
    });

    debugPrint('VersionService: Tentative de connexion au Realtime...');
    _supabase
        .channel('app_config_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'app_config',
          callback: (payload) {
            debugPrint(
              'VersionService [REALTIME PAYLOAD]: ${payload.toString()}',
            );
            final data = payload.newRecord;
            if (data.isEmpty) return;
            if (data.containsKey('show_premium')) {
              final newValue = data['show_premium'] == true;
              if (_showPremiumBase != newValue) {
                _showPremiumBase = newValue;
                showPremiumNotifier.value = showPremium;
                debugPrint(
                  'VersionService [REALTIME]: show_premium changé → $showPremium',
                );
              }
            }
            // Synchronise la configuration des swipes en temps réel
            _applySwipeConfig(data);
            debugPrint('VersionService [REALTIME]: swipe_limit → $swipeLimit');
            // Synchronise le trial CV en temps réel
            _applyCvTrialConfig(data);
            debugPrint(
              'VersionService [REALTIME]: cv_trial_active → $cvTrialActive',
            );
            // Synchronise le trial adaptation IA en temps réel
            _applyAiAdaptTrialConfig(data);
            debugPrint(
              'VersionService [REALTIME]: ai_adapt_enabled → $aiAdaptEnabled, ai_adapt_trial_active → $aiAdaptTrialActive',
            );
            // Synchronise la tarification en temps réel
            _applyPricingConfig(data);
            _applyPremiumFeatureToggles(data);
            debugPrint(
              'VersionService [REALTIME]: premiumPriceCfa → $premiumPriceCfa, extraCvPriceCfa → $extraCvPriceCfa',
            );
            // Synchronise la version et le mode maintenance
            _applyVersionAndMaintenanceConfig(data);
            debugPrint(
              'VersionService [REALTIME]: app_stopped → $appStopped, min_version → $minVersion',
            );

            // Évalue immédiatement le statut sur le context de navigation actif
            final ctx = AppRouter.navigatorKey.currentContext;
            if (ctx != null && ctx.mounted) {
              evaluateStatus(ctx);
            }
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
      _applyPremiumFeatureToggles(Map<String, dynamic>.from(response));
      _applyVersionAndMaintenanceConfig(Map<String, dynamic>.from(response));

      debugPrint(
        'VersionService: Initialisation terminée. showPremium: $showPremium, swipeLimit: $swipeLimit, appStopped: $appStopped, minVersion: $minVersion',
      );

      if (context.mounted) {
        await evaluateStatus(context);
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

  /// Affiche le dialogue bloquant de maintenance / arrêt
  static void _showMaintenanceDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Bloquant
      builder: (dialogContext) {
        activeDialogContext = dialogContext;
        return WillPopScope(
          onWillPop: () async => false, // Empêche le retour arrière
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.pause_circle_filled_rounded,
                  color: Color(0xFFEF4444),
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    maintenanceTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              maintenanceMessage,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    dismissDialogIfOpen();
                    await checkVersion(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Réessayer',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      isDialogShowing = false;
      activeDialogContext = null;
    });
  }

  /// Affiche le dialogue bloquant de mise à jour requise
  static void _showUpdateDialog(BuildContext context, String storeUrl) {
    showDialog(
      context: context,
      barrierDismissible: false, // Bloquant
      builder: (dialogContext) {
        activeDialogContext = dialogContext;
        return WillPopScope(
          onWillPop: () async => false, // Empêche le retour arrière
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
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
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'METTRE À JOUR MAINTENANT',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      isDialogShowing = false;
      activeDialogContext = null;
    });
  }
}
