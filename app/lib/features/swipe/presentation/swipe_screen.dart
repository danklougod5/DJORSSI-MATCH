import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:djossimatch/features/swipe/presentation/djossi_swipe_card.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/version_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:djossimatch/core/cache/local_cache.dart';
import 'package:djossimatch/core/services/match_notifier.dart';
import 'package:djossimatch/core/services/profile_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:djossimatch/core/utils/tag_normalizer.dart';
import 'package:djossimatch/features/cv_generator/models/cv_model.dart';
import 'package:djossimatch/features/cv_generator/services/cv_ai_import_service.dart';
import 'package:djossimatch/features/cv_generator/services/cv_storage_service.dart';
import 'package:djossimatch/features/cv_generator/utils/cv_pdf_generator.dart';
import 'package:djossimatch/core/services/cv_quota_service.dart';
import 'package:djossimatch/features/cv_generator/widgets/cv_paywall_sheet.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:flutter/cupertino.dart';
import 'package:djossimatch/core/services/announcement_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:djossimatch/core/routing/app_router.dart';
import 'package:djossimatch/features/cv_generator/widgets/cv_basic_info_editor.dart';
import 'package:djossimatch/features/cv_generator/widgets/cv_skills_editor.dart';
import 'package:djossimatch/features/cv_generator/widgets/cv_experiences_editor.dart';
import 'package:djossimatch/features/cv_generator/widgets/cv_education_editor.dart';
import 'package:djossimatch/features/cv_generator/widgets/cv_projects_editor.dart';
import 'package:djossimatch/features/cv_generator/widgets/cv_activities_editor.dart';
import 'package:djossimatch/features/cv_generator/widgets/cv_ai_loading_dialog.dart';
import 'package:intl/intl.dart';

class SwipeScreen extends StatefulWidget {
  final String? jobId;
  const SwipeScreen({super.key, this.jobId});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> {
  final _supabase = Supabase.instance.client;
  final CardSwiperController _controller = CardSwiperController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _jobs = [];
  List<String> _userSkills = [];

  // Cache des scores de matching pour éviter les recalculs à chaque frame
  final Map<String, int> _matchScoreCache = {};

  // Clé pour forcer la reconstruction du CardSwiper quand les secteurs changent
  int _swiperKey = 0;
  int _currentCardIndex = 0;

  // Nouveaux états pour le Premium
  int _swipeCount = 0;
  int _lastWrittenSwipeCount = 0; // Compteur de la dernière écriture en DB
  bool _isPremium = false;
  bool get _hasUnlimitedSwipes =>
      _isPremium && VersionService.featUnlimitedSwipes;
  String? _cvUrl;
  String? _fullName;
  String? _sexe;
  bool _hasUnreadNotifications = false;
  CardSwiperDirection _dragDirection = CardSwiperDirection.none;

  // File d'attente pour les envois d'email (éviter le rate-limiting)
  final List<Map<String, dynamic>> _emailQueue = [];
  bool _isProcessingQueue = false;

  // Debounce pour éviter les rechargements multiples (Realtime + ProfileNotifier)
  DateTime _lastFullReload = DateTime(2000);
  static const int _reloadDebounceSeconds = 5;

  // Cache local des IDs déjà swipés (évite de re-télécharger 11K+ lignes)
  Set<String> _cachedSwipedIds = {};

  StreamSubscription<List<Map<String, dynamic>>>? _profileSubscription;
  RealtimeChannel? _jobsRealtimeChannel;
  int _currentLoadSessionId = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtime();
    _setupJobsRealtime();
    _listenToProfileChanges();
    _checkUnreadNotifications();
    VersionService.aiAdaptEnabledNotifier.addListener(_onAiAdaptConfigChanged);

    // Initialiser l'écouteur d'annonces de l'app sur l'écran des Swipes après le rendu du premier frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AnnouncementService.instance.initialize();
      }
    });
  }

  Future<void> _checkUnreadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastViewed =
          prefs.getString('last_notifications_view') ??
          DateTime(2000).toIso8601String();

      final userId = _supabase.auth.currentUser?.id;
      final response = await _supabase
          .from('notifications')
          .select('created_at')
          .or('target.eq.all${userId != null ? ',target.eq.$userId' : ''}')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && mounted) {
        final latestNotifDate = DateTime.parse(response['created_at']);
        final lastViewedDate = DateTime.parse(lastViewed);

        setState(() {
          _hasUnreadNotifications = latestNotifDate.isAfter(lastViewedDate);
        });
      }
    } catch (e) {
      debugPrint('Erreur check notifications: $e');
    }
  }

  void _listenToProfileChanges() {
    ProfileNotifier.stream.addListener(() {
      if (mounted) {
        // Debounce : ignorer si un rechargement a eu lieu récemment (ex: via Realtime)
        final now = DateTime.now();
        if (now.difference(_lastFullReload).inSeconds <
            _reloadDebounceSeconds) {
          debugPrint(
            '*** [NOTIFIER] Rechargement ignoré (debounce, dernier il y a ${now.difference(_lastFullReload).inSeconds}s) ***',
          );
          return;
        }
        debugPrint(
          '*** [NOTIFIER] Changement de profil détecté via ProfileNotifier ! Rechargement... ***',
        );
        // Vider le cache de matching
        _matchScoreCache.clear();
        setState(() {
          _isLoading = true;
          _jobs = [];
          _swiperKey++; // Force la reconstruction du CardSwiper
          _currentCardIndex = 0;
        });
        _loadData(forceRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    AnnouncementService.instance.dispose();
    _jobsRealtimeChannel?.unsubscribe();
    _profileSubscription?.cancel();
    VersionService.aiAdaptEnabledNotifier.removeListener(
      _onAiAdaptConfigChanged,
    );
    _controller.dispose();
    _saveFinalSwipeCount();
    super.dispose();
  }

  void _onAiAdaptConfigChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _saveFinalSwipeCount() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null && _swipeCount != _lastWrittenSwipeCount) {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      _supabase
          .from('profiles')
          .update({'daily_swipe_count': _swipeCount, 'last_swipe_date': today})
          .eq('id', userId)
          .catchError((e) {
            debugPrint('Erreur sauvegarde finale daily_swipe_count: $e');
            return null;
          });
    }
  }

  void _setupRealtime() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _profileSubscription = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((data) {
          if (data.isNotEmpty && mounted) {
            if (data.first['is_blocked'] == true) {
              Supabase.instance.client.auth.signOut();
              AppRouter.router.go('/auth');
              return;
            }

            // Détecter un changement de secteurs pour recharger les offres
            final newSkills = List<String>.from(data.first['skills'] ?? []);
            final oldSkills = List<String>.from(_userSkills);
            final skillsChanged = !_listsEqual(oldSkills, newSkills);

            setState(() {
              final isPremium = data.first['is_premium'] ?? false;
              final premiumUntilRaw = data.first['premium_until'];
              if (isPremium && premiumUntilRaw != null) {
                final premiumUntil = DateTime.parse(premiumUntilRaw);
                _isPremium = premiumUntil.isAfter(DateTime.now());
              } else {
                _isPremium = isPremium;
              }
              if (!VersionService.showPremium) {
                _isPremium = true;
              }
              _cvUrl = data.first['cv_url'];
              _fullName = data.first['full_name'];
              _sexe = data.first['sexe'];
            });

            // Si les secteurs ont changé → recharger complètement les offres
            if (skillsChanged) {
              // Debounce : ignorer si un rechargement a eu lieu récemment
              final now = DateTime.now();
              if (now.difference(_lastFullReload).inSeconds <
                  _reloadDebounceSeconds) {
                debugPrint('*** [REALTIME] Rechargement ignoré (debounce) ***');
                return;
              }
              debugPrint(
                '*** [REALTIME] Changement de secteurs détecté ! Ancien: $oldSkills → Nouveau: $newSkills ***',
              );
              // 1. Mettre à jour immédiatement les skills AVANT _loadData
              _userSkills = newSkills;
              // 2. Vider le cache de matching (les scores sont obsolètes)
              _matchScoreCache.clear();
              // 3. Forcer le rechargement visuel complet
              setState(() {
                _isLoading = true;
                _jobs = [];
                _swiperKey++; // Force la reconstruction du CardSwiper
                _currentCardIndex = 0;
              });
              // 4. Recharger les offres avec les nouveaux secteurs
              _loadData(forceRefresh: true);
            }
          }
        });
  }

  void _setupJobsRealtime() {
    _jobsRealtimeChannel = _supabase
        .channel('public:jobs')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'jobs',
          callback: (payload) {
            final newJob = payload.newRecord;
            final isApproved = newJob['is_approved'] == true;
            debugPrint(
              '*** [REALTIME JOBS] Nouvelle offre insérée: ${newJob['job_title']} | Approuvée: $isApproved ***',
            );
            if (isApproved && mounted) {
              // Debounce pour éviter les rechargements multiples
              final now = DateTime.now();
              if (now.difference(_lastFullReload).inSeconds <
                  _reloadDebounceSeconds) {
                debugPrint(
                  '*** [REALTIME JOBS] Rechargement ignoré (debounce) ***',
                );
                return;
              }
              _lastFullReload = now;
              _loadData(forceRefresh: true);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'jobs',
          callback: (payload) {
            final updatedJob = payload.newRecord;
            final isApproved = updatedJob['is_approved'] == true;
            final oldApproved = payload.oldRecord['is_approved'] == true;
            // Recharger seulement si le job vient d'être approuvé
            if (isApproved && !oldApproved && mounted) {
              debugPrint(
                '*** [REALTIME JOBS] Offre approuvée: ${updatedJob['job_title']} ***',
              );
              final now = DateTime.now();
              if (now.difference(_lastFullReload).inSeconds <
                  _reloadDebounceSeconds) {
                return;
              }
              _lastFullReload = now;
              _loadData(forceRefresh: true);
            }
          },
        );
    _jobsRealtimeChannel?.subscribe();
  }

  /// Compare deux listes indépendamment de l'ordre
  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sortedA = List<String>.from(a)..sort();
    final sortedB = List<String>.from(b)..sort();
    for (int i = 0; i < sortedA.length; i++) {
      if (sortedA[i] != sortedB[i]) return false;
    }
    return true;
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    final sessionId = ++_currentLoadSessionId;

    // 0a. Charger les skills du cache SEULEMENT si pas déjà définis (par le realtime)
    if (_userSkills.isEmpty) {
      try {
        final cachedSkills = await LocalCache.load(LocalCache.skillsKey);
        if (cachedSkills != null && cachedSkills is List) {
          if (sessionId != _currentLoadSessionId) return;
          _userSkills = List<String>.from(cachedSkills);
        }
      } catch (e) {
        debugPrint('Erreur lecture cache skills: $e');
      }
    }

    // 0b. Toujours charger les swiped IDs depuis le cache local pour filtrer correctement
    try {
      final cachedSwipedData = await LocalCache.load(LocalCache.swipedIdsKey);
      if (cachedSwipedData != null && cachedSwipedData is List) {
        if (sessionId != _currentLoadSessionId) return;
        _cachedSwipedIds = Set<String>.from(
          cachedSwipedData.map((e) => e.toString()),
        );
        debugPrint(
          '*** [CACHE] Swiped IDs chargés depuis le cache local (${_cachedSwipedIds.length} IDs) ***',
        );
      }
    } catch (e) {
      debugPrint('Erreur lecture cache swiped IDs: $e');
    }

    // 0c. Utiliser le cache frais si disponible et qu'on ne force pas le rafraîchissement
    try {
      final isFresh = await LocalCache.isFresh(
        LocalCache.jobsKey,
        LocalCache.jobsTTL,
      );
      if (isFresh && !forceRefresh) {
        final cachedJobs = await LocalCache.load(LocalCache.jobsKey);
        if (cachedJobs != null && cachedJobs is List && mounted) {
          if (sessionId != _currentLoadSessionId) return;
          var cachedList = List<Map<String, dynamic>>.from(cachedJobs);
          // BUGFIX: Filtrer les offres déjà swipées depuis le cache
          if (_cachedSwipedIds.isNotEmpty) {
            final beforeCount = cachedList.length;
            cachedList = cachedList.where((job) {
              final jobId = job['id']?.toString() ?? '';
              return !_cachedSwipedIds.contains(jobId);
            }).toList();
            debugPrint(
              '*** [CACHE] Filtrage swiped IDs: $beforeCount → ${cachedList.length} offres (${beforeCount - cachedList.length} déjà swipées retirées) ***',
            );
          }
          if (_sectorSkills.isNotEmpty) {
            cachedList = cachedList.where((job) {
              return _calculateMatchScore(job) > 0;
            }).toList();
            cachedList.sort((a, b) {
              final scoreA = _calculateMatchScore(a);
              final scoreB = _calculateMatchScore(b);
              return scoreB.compareTo(scoreA);
            });
          }
          if (sessionId != _currentLoadSessionId) return;
          setState(() {
            _jobs = cachedList;
            _isLoading = false;
          });
          debugPrint(
            '*** [CACHE] Emplois chargés depuis le cache frais (TTL) - Pas d\'appel réseau ***',
          );
          return; // Évite les appels réseau Supabase !
        }
      }
    } catch (e) {
      debugPrint('Erreur lecture cache jobs frais: $e');
    }

    // Charger le cache en arrière-plan ou immédiatement si vide
    try {
      final cachedJobs = await LocalCache.load(LocalCache.jobsKey);
      if (cachedJobs != null &&
          cachedJobs is List &&
          mounted &&
          _jobs.isEmpty) {
        if (sessionId != _currentLoadSessionId) return;
        var cachedList = List<Map<String, dynamic>>.from(cachedJobs);
        // BUGFIX: Filtrer les offres déjà swipées depuis le cache fallback aussi
        if (_cachedSwipedIds.isNotEmpty) {
          cachedList = cachedList.where((job) {
            final jobId = job['id']?.toString() ?? '';
            return !_cachedSwipedIds.contains(jobId);
          }).toList();
        }
        if (_sectorSkills.isNotEmpty) {
          cachedList = cachedList.where((job) {
            return _calculateMatchScore(job) > 0;
          }).toList();
          cachedList.sort((a, b) {
            final scoreA = _calculateMatchScore(a);
            final scoreB = _calculateMatchScore(b);
            return scoreB.compareTo(scoreA);
          });
        }
        if (sessionId != _currentLoadSessionId) return;
        setState(() {
          _jobs = cachedList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur lecture cache jobs: $e');
    }

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 1. Récupérer les infos du profil (is_premium, skills, and daily swipe limits)
      final profileResponse = await _supabase
          .from('profiles')
          .select(
            'skills, is_premium, premium_until, full_name, cv_url, sexe, daily_swipe_count, last_swipe_date',
          )
          .eq('id', userId)
          .maybeSingle();

      if (sessionId != _currentLoadSessionId) return;

      if (profileResponse != null) {
        final isPremium = profileResponse['is_premium'] ?? false;
        final premiumUntilRaw = profileResponse['premium_until'];
        if (isPremium && premiumUntilRaw != null) {
          final premiumUntil = DateTime.parse(premiumUntilRaw);
          _isPremium = premiumUntil.isAfter(DateTime.now());
        } else {
          _isPremium = isPremium;
        }
        if (!VersionService.showPremium) {
          _isPremium = true;
        }
        _cvUrl = profileResponse['cv_url'];
        _fullName = profileResponse['full_name'];
        _sexe = profileResponse['sexe'];
      }

      if (profileResponse != null && profileResponse['skills'] != null) {
        _userSkills = List<String>.from(profileResponse['skills']);
        // Sauvegarder les skills dans le cache pour le prochain démarrage
        await LocalCache.save(LocalCache.skillsKey, _userSkills);
      }

      // 2. Récupérer les IDs des jobs déjà swipés — DEPUIS LE CACHE si possible
      Set<String> swipedJobIds;
      final cachedSwipedIds = await LocalCache.loadIfFresh(
        LocalCache.swipedIdsKey,
        LocalCache.swipedIdsTTL,
      );
      if (sessionId != _currentLoadSessionId) return;
      if (cachedSwipedIds != null && cachedSwipedIds is List && !forceRefresh) {
        swipedJobIds = Set<String>.from(cachedSwipedIds);
        debugPrint(
          '*** [CACHE] Swiped IDs chargés depuis le cache (${swipedJobIds.length} IDs) ***',
        );
      } else {
        // Cache expiré ou forceRefresh → charger depuis Supabase
        final swipedResponse = await _supabase
            .from('swipes_log')
            .select('job_id')
            .eq('user_id', userId);

        if (sessionId != _currentLoadSessionId) return;
        swipedJobIds = (swipedResponse as List)
            .where((s) => s['job_id'] != null)
            .map((s) => s['job_id'].toString())
            .toSet();

        // Sauvegarder dans le cache
        await LocalCache.save(LocalCache.swipedIdsKey, swipedJobIds.toList());
        debugPrint(
          '*** [NETWORK] Swiped IDs chargés depuis Supabase (${swipedJobIds.length} IDs) et mis en cache ***',
        );
      }
      _cachedSwipedIds = swipedJobIds;

      // 2.5 Compteur de swipes quotidien — LOCAL avec synchronisation DB si cache manquant/vidé
      final today = DateTime.now().toIso8601String().substring(0, 10);
      try {
        final cachedDate = await LocalCache.load(LocalCache.swipeCountDateKey);
        final cachedCount = await LocalCache.load(LocalCache.swipeCountKey);
        if (sessionId != _currentLoadSessionId) return;
        if (cachedDate == today && cachedCount != null) {
          _swipeCount = cachedCount as int;
          debugPrint('*** [CACHE] Compteur swipes du jour: $_swipeCount ***');
        } else {
          // Si le cache est absent/obsolète (ex: après déconnexion), synchroniser depuis la DB
          final dbDate = profileResponse?['last_swipe_date']?.toString();
          final dbCount = profileResponse?['daily_swipe_count'] as int? ?? 0;
          if (dbDate == today) {
            _swipeCount = dbCount;
          } else {
            _swipeCount = 0;
          }
          await LocalCache.save(LocalCache.swipeCountDateKey, today);
          await LocalCache.save(LocalCache.swipeCountKey, _swipeCount);
          debugPrint(
            '*** [DB-SYNC] Compteur swipes du jour synchronisé depuis la DB : $_swipeCount ***',
          );
        }
      } catch (e) {
        debugPrint('Erreur lors du comptage des swipes: $e');
        _swipeCount = 0;
      }
      _lastWrittenSwipeCount = _swipeCount;

      // 3. Récupérer les offres non swipées — PAGINÉ (50 max) avec filtrage serveur
      final swipedIdsList = swipedJobIds.toList();
      var jobsQuery = _supabase
          .from('jobs')
          .select(
            'id, job_title, company_name, salary_range, location, required_level, experience, contact_email, whatsapp_number, description, is_ai_verified, tags, deadline, application_link, requires_cover_letter, cover_letter_instructions, created_at',
          )
          .eq('is_approved', true);

      debugPrint('*** [DB-QUERY] _userSkills = $_userSkills ***');
      debugPrint('*** [DB-QUERY] _sectorSkills = $_sectorSkills ***');
      // Filtrage serveur par secteurs/compétences de l'utilisateur
      if (_sectorSkills.isNotEmpty) {
        final orConditions = <String>[];
        for (final skill in _sectorSkills) {
          final escapedSkill = skill.replaceAll("'", "''");
          orConditions.add('tags.cs.{"$escapedSkill"}');
          orConditions.add('job_title.ilike.%$escapedSkill%');
        }
        if (orConditions.isNotEmpty) {
          final condString = orConditions.join(',');
          debugPrint('*** [DB-QUERY] Adding OR filter: $condString ***');
          jobsQuery = jobsQuery.or(condString);
        }
      } else {
        debugPrint(
          '*** [DB-QUERY] No OR filter added because _sectorSkills is empty ***',
        );
      }

      // Filtrage serveur : exclure les jobs déjà swipés (si pas trop d'IDs)
      if (swipedIdsList.isNotEmpty && swipedIdsList.length <= 500) {
        jobsQuery = jobsQuery.not('id', 'in', '(${swipedIdsList.join(",")})');
      }

      final jobsResponse = await jobsQuery
          .order('created_at', ascending: false)
          .limit(50);

      if (sessionId != _currentLoadSessionId) return;

      var allJobs = List<Map<String, dynamic>>.from(jobsResponse);
      // Fallback client-side filter si trop d'IDs pour le filtre serveur
      if (swipedIdsList.length > 500) {
        allJobs = allJobs
            .where((job) => !swipedJobIds.contains(job['id'].toString()))
            .toList();
      }

      // Récupérer le job spécifique ciblé par la notification si spécifié
      if (widget.jobId != null) {
        try {
          final targetJobResponse = await _supabase
              .from('jobs')
              .select(
                'id, job_title, company_name, salary_range, location, required_level, experience, contact_email, whatsapp_number, description, is_ai_verified, tags, deadline, application_link, requires_cover_letter, cover_letter_instructions, created_at',
              )
              .eq('id', widget.jobId!)
              .maybeSingle();

          if (sessionId != _currentLoadSessionId) return;

          if (targetJobResponse != null) {
            // Retirer le job de la liste s'il s'y trouve déjà (pour éviter les doublons)
            allJobs.removeWhere((job) => job['id'].toString() == widget.jobId);
            // L'insérer au tout début de la liste (index 0)
            allJobs.insert(0, targetJobResponse);
            debugPrint(
              '*** [NOTIF] Job cible ${widget.jobId} ajouté en haut de la pile ***',
            );
          }
        } catch (e) {
          debugPrint('Erreur lors du chargement du job ciblé par notif: $e');
        }
      }

      final now = DateTime.now();
      final jobsBeforeExpiryFilter = allJobs.length;
      allJobs = allJobs.where((job) => !_isJobExpired(job, now: now)).toList();
      debugPrint(
        '*** [EXPIRY] ${jobsBeforeExpiryFilter - allJobs.length} offre(s) expirée(s) retirée(s) du swipe ***',
      );

      // 4. Trier et FILTRER par matching pour tous les utilisateurs
      if (_userSkills.isNotEmpty) {
        debugPrint('*** [MATCHING] Tags utilisateur (tous): $_userSkills ***');
        debugPrint(
          '*** [MATCHING] Tags sectoriels (pour le matching): $_sectorSkills ***',
        );
        debugPrint(
          '*** [MATCHING] Tags génériques (ignorés): ${_userSkills.where((s) => _isGenericTag(s)).toList()} ***',
        );
        debugPrint(
          '*** [MATCHING] Nombre total de jobs avant filtrage: ${allJobs.length} ***',
        );
        for (final job in allJobs) {
          debugPrint(
            '  - ID: ${job['id']} | Title: ${job['job_title']} | Tags: ${job['tags']}',
          );
        }

        // Pré-calculer les scores de matching
        _matchScoreCache.clear();
        for (final job in allJobs) {
          final jobId = job['id']?.toString() ?? '';
          _matchScoreCache[jobId] = _calculateMatchScore(job);
        }

        // FILTRAGE STRICT : retirer les offres sans aucun rapport avec le secteur
        final matchedJobs = allJobs.where((job) {
          final jobId = job['id']?.toString() ?? '';
          final score = _matchScoreCache[jobId] ?? 0;
          return score > 0; // Seuls les jobs avec un vrai match sont gardés
        }).toList();

        debugPrint(
          '*** [MATCHING] Nombre de jobs APRÈS filtrage: ${matchedJobs.length} (${allJobs.length - matchedJobs.length} offres non pertinentes retirées) ***',
        );

        // Trier les jobs restants par score (meilleur match en premier)
        matchedJobs.sort((a, b) {
          final scoreA = _matchScoreCache[a['id']?.toString() ?? ''] ?? 0;
          final scoreB = _matchScoreCache[b['id']?.toString() ?? ''] ?? 0;
          return scoreB.compareTo(scoreA);
        });

        // Log des 5 premiers résultats pour vérification
        for (int i = 0; i < matchedJobs.length && i < 5; i++) {
          final job = matchedJobs[i];
          final jobId = job['id']?.toString() ?? '';
          final jobSectorTags = List<String>.from(
            job['tags'] ?? [],
          ).where((t) => !_isGenericTag(t.toLowerCase().trim())).toList();
          debugPrint(
            '*** [MATCHING] #${i + 1} Score=${_matchScoreCache[jobId]} | ${job['job_title']} | Tags sectoriels: $jobSectorTags ***',
          );
        }

        // Si l'utilisateur a des skills mais aucun match, on ne montre rien
        // pour éviter de proposer des offres "hors sujet" (dérive)
        if (matchedJobs.isEmpty && _userSkills.isNotEmpty) {
          debugPrint(
            '*** [MATCHING] ⚠️ Aucun job ne correspond. On ne montre rien pour éviter la dérive. ***',
          );
          allJobs.clear();
        } else if (matchedJobs.isNotEmpty) {
          allJobs
            ..clear()
            ..addAll(matchedJobs);
        }
      }

      if (sessionId != _currentLoadSessionId) return;

      // 5. Sauvegarder dans le cache pour la prochaine fois
      await LocalCache.save(LocalCache.jobsKey, allJobs);

      // Marquer le timestamp du dernier rechargement complet (debounce)
      _lastFullReload = DateTime.now();

      if (mounted) {
        setState(() {
          _jobs = allJobs;
          _isLoading = false;
          _swiperKey++; // Force la reconstruction complète du swiper avec les nouvelles données
          _currentCardIndex = 0;
        });

        // Afficher un petit message si aucune nouvelle offre n'a été trouvée
        if (allJobs.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Scan terminé : aucune nouvelle offre correspondante.',
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement réseau: $e');
      if (sessionId != _currentLoadSessionId) return;
      // Si on a déjà des données (du cache), on ne masque pas tout
      if (mounted) {
        setState(() => _isLoading = false);
        // Optionnel : avertir l'utilisateur qu'il est hors-ligne
        if (_jobs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mode hors-ligne : affichage des offres en cache.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  /// Charge le prochain batch de 50 jobs (pagination) sans recharger tout
  bool _isLoadingNextBatch = false;
  Future<void> _loadNextBatch() async {
    if (_isLoadingNextBatch) return;
    _isLoadingNextBatch = true;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      var jobsQuery = _supabase
          .from('jobs')
          .select(
            'id, job_title, company_name, salary_range, location, required_level, experience, contact_email, whatsapp_number, description, is_ai_verified, tags, deadline, application_link, requires_cover_letter, cover_letter_instructions, created_at',
          )
          .eq('is_approved', true);

      debugPrint('*** [DB-QUERY-PAGINATION] _userSkills = $_userSkills ***');
      debugPrint(
        '*** [DB-QUERY-PAGINATION] _sectorSkills = $_sectorSkills ***',
      );
      // Filtrage serveur par secteurs/compétences de l'utilisateur
      if (_sectorSkills.isNotEmpty) {
        final orConditions = <String>[];
        for (final skill in _sectorSkills) {
          final escapedSkill = skill.replaceAll("'", "''");
          orConditions.add('tags.cs.{"$escapedSkill"}');
          orConditions.add('job_title.ilike.%$escapedSkill%');
        }
        if (orConditions.isNotEmpty) {
          final condString = orConditions.join(',');
          debugPrint(
            '*** [DB-QUERY-PAGINATION] Adding OR filter: $condString ***',
          );
          jobsQuery = jobsQuery.or(condString);
        }
      } else {
        debugPrint(
          '*** [DB-QUERY-PAGINATION] No OR filter added because _sectorSkills is empty ***',
        );
      }

      // Filtrage serveur : exclure les jobs déjà swipés + déjà affichés
      final excludeIds = <String>{..._cachedSwipedIds};
      for (final job in _jobs) {
        final id = job['id']?.toString();
        if (id != null) excludeIds.add(id);
      }
      final excludeList = excludeIds.toList();

      if (excludeList.isNotEmpty && excludeList.length <= 500) {
        jobsQuery = jobsQuery.not('id', 'in', '(${excludeList.join(",")})');
      }

      final response = await jobsQuery
          .order('created_at', ascending: false)
          .limit(50);

      var newJobs = List<Map<String, dynamic>>.from(response);

      // Fallback client-side filter si trop d'IDs
      if (excludeList.length > 500) {
        newJobs = newJobs
            .where((job) => !excludeIds.contains(job['id'].toString()))
            .toList();
      }

      final now = DateTime.now();
      newJobs = newJobs.where((job) => !_isJobExpired(job, now: now)).toList();

      // Filtrer par matching
      if (_sectorSkills.isNotEmpty) {
        newJobs = newJobs
            .where((job) => _calculateMatchScore(job) > 0)
            .toList();
        newJobs.sort((a, b) {
          final scoreA = _calculateMatchScore(a);
          final scoreB = _calculateMatchScore(b);
          return scoreB.compareTo(scoreA);
        });
      }

      if (newJobs.isNotEmpty && mounted) {
        setState(() {
          _jobs.addAll(newJobs);
        });
        debugPrint(
          '*** [PAGINATION] ${newJobs.length} nouveaux jobs ajoutés (total: ${_jobs.length}) ***',
        );
      } else {
        debugPrint('*** [PAGINATION] Aucun nouveau job disponible ***');
      }
    } catch (e) {
      debugPrint('Erreur chargement batch suivant: $e');
    } finally {
      _isLoadingNextBatch = false;
    }
  }

  bool _isGenericTag(String tag) {
    return TagNormalizer.isGeneric(tag);
  }

  /// Retourne les skills de l'utilisateur en filtrant les tags génériques
  List<String> get _sectorSkills {
    return _userSkills.where((s) => !_isGenericTag(s)).toList();
  }

  DateTime? _parseJobDate(dynamic value, {bool endOfDay = false}) {
    if (value == null) return null;

    if (value is DateTime) {
      return endOfDay
          ? DateTime(value.year, value.month, value.day, 23, 59, 59, 999)
          : value;
    }

    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    final slashParts = raw.split('/');
    if (slashParts.length == 3) {
      final day = int.tryParse(slashParts[0]);
      final month = int.tryParse(slashParts[1]);
      final year = int.tryParse(slashParts[2]);

      if (day != null && month != null && year != null) {
        return DateTime(
          year,
          month,
          day,
          endOfDay ? 23 : 0,
          endOfDay ? 59 : 0,
          endOfDay ? 59 : 0,
          endOfDay ? 999 : 0,
        );
      }
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;

    return endOfDay
        ? DateTime(parsed.year, parsed.month, parsed.day, 23, 59, 59, 999)
        : parsed;
  }

  DateTime? _getEffectiveExpiryDate(Map<String, dynamic> job) {
    final explicitDeadline = _parseJobDate(job['deadline'], endOfDay: true);
    if (explicitDeadline != null) return explicitDeadline;

    final createdAt = _parseJobDate(job['created_at']);
    if (createdAt == null) return null;

    final fallback = createdAt.add(const Duration(days: 21));
    return DateTime(
      fallback.year,
      fallback.month,
      fallback.day,
      23,
      59,
      59,
      999,
    );
  }

  bool _isJobExpired(Map<String, dynamic> job, {DateTime? now}) {
    final expiryDate = _getEffectiveExpiryDate(job);
    if (expiryDate == null) return false;
    return expiryDate.isBefore(now ?? DateTime.now());
  }

  String? _getDisplayDeadline(Map<String, dynamic> job) {
    final expiryDate = _getEffectiveExpiryDate(job);
    if (expiryDate == null) return null;
    return DateFormat('dd/MM/yyyy', 'fr_FR').format(expiryDate);
  }

  List<String> _getExpandedKeywords(String userSkill) {
    return TagNormalizer.getExpandedKeywords(userSkill).toList();
  }

  int _calculateMatchScore(Map<String, dynamic> job) {
    if (widget.jobId != null && job['id']?.toString() == widget.jobId) {
      return 1000; // Score maximum pour l'offre ciblée par notification
    }
    if (_userSkills.isEmpty) return 50;

    double totalScore = 0;
    int matchesCount = 0;

    // On vérifie si l'utilisateur a des compétences sectorielles (non-contrat et non-génériques)
    final hasSectorSkills = _userSkills.any((s) {
      final sLower = s.toLowerCase().trim();
      return !_isContractType(sLower) && !_isGenericTag(sLower);
    });
    bool matchedSectorSkill = false;

    // Normalisation basique (minuscules)
    final jobTitle = (job['job_title'] as String?)?.toLowerCase().trim() ?? '';
    final jobSpecialty =
        (job['specialty'] as String?)?.toLowerCase().trim() ?? '';
    final jobDescription = (job['description'] as String?)?.toLowerCase() ?? '';
    final allJobTags = List<String>.from(
      job['tags'] ?? [],
    ).map((t) => t.toLowerCase().trim()).toList();

    // On matche contre TOUS les skills de l'utilisateur pour être plus précis
    for (final skill in _userSkills) {
      double currentSkillScore = 0;
      final skillLower = skill.toLowerCase().trim();
      final isContractTag = _isContractType(skillLower);
      final isSectorSkill = !isContractTag && !_isGenericTag(skillLower);

      bool matchedThisSkill = false;

      // 1. MATCH DIRECT PAR TAG (POIDS TRÈS FORT)
      for (final jobTag in allJobTags) {
        if (TagNormalizer.normalizeKey(jobTag) ==
            TagNormalizer.normalizeKey(skillLower)) {
          currentSkillScore += isContractTag ? 400 : 300;
          matchedThisSkill = true;
          break;
        }
        // Match partiel uniquement pour les mots suffisamment longs
        if (skillLower.length > 3 &&
            (TagNormalizer.normalizeKey(
                  jobTag,
                ).contains(TagNormalizer.normalizeKey(skillLower)) ||
                TagNormalizer.normalizeKey(
                  skillLower,
                ).contains(TagNormalizer.normalizeKey(jobTag)))) {
          currentSkillScore += 150;
          matchedThisSkill = true;
          break;
        }
      }

      // 2. MATCH PAR SPÉCIALITÉ (POIDS FORT)
      if (!matchedThisSkill && jobSpecialty.isNotEmpty) {
        if (TagNormalizer.normalizeKey(jobSpecialty) ==
            TagNormalizer.normalizeKey(skillLower)) {
          currentSkillScore += 150;
          matchedThisSkill = true;
        } else if (skillLower.length > 3 &&
            (TagNormalizer.normalizeKey(
                  jobSpecialty,
                ).contains(TagNormalizer.normalizeKey(skillLower)) ||
                TagNormalizer.normalizeKey(
                  skillLower,
                ).contains(TagNormalizer.normalizeKey(jobSpecialty)))) {
          currentSkillScore += 80;
          matchedThisSkill = true;
        }
      }

      // 3. RECHERCHE DE MOTS-CLÉS (POIDS MOYEN)
      if (!matchedThisSkill) {
        final keywords = _getExpandedKeywords(skill);
        for (final kw in keywords) {
          final kwLower = kw.toLowerCase().trim();
          if (_matchWord(jobTitle, kwLower)) {
            currentSkillScore += 100;
            matchedThisSkill = true;
            break;
          }
          if (allJobTags.any((tag) => _matchWord(tag, kwLower))) {
            currentSkillScore += 50;
            matchedThisSkill = true;
            break;
          }
        }
      }

      // 4. Bonus Description
      if (!matchedThisSkill || isContractTag) {
        if (_matchWord(jobDescription, skillLower)) {
          currentSkillScore += matchedThisSkill ? 20 : 40;
          matchedThisSkill = true;
        }
      }

      if (matchedThisSkill) {
        totalScore += currentSkillScore;
        matchesCount++;
        if (isSectorSkill) {
          matchedSectorSkill = true;
        }
      }
    }

    // FILTRAGE STRICT : Si l'utilisateur a des critères mais qu'aucun ne matche ce job
    if (matchesCount == 0 && _userSkills.isNotEmpty) {
      return -100;
    }

    // Si l'utilisateur a des critères sectoriels, le job DOIT correspondre à au moins un critère sectoriel
    if (hasSectorSkills && !matchedSectorSkill) {
      return -100;
    }

    // BONUS MULTI-MATCH : On récompense les jobs qui cochent plusieurs cases
    if (matchesCount > 1) {
      totalScore += (matchesCount * 30);
    }

    // 5. BONUS PREMIUM : Les utilisateurs premium voient les offres récentes en priorité
    if (_isPremium) {
      final createdAt = job['created_at'] as String?;
      if (createdAt != null) {
        try {
          final jobDate = DateTime.parse(createdAt);
          final hoursAgo = DateTime.now().difference(jobDate).inHours;
          if (hoursAgo <= 24) {
            totalScore += 50;
          } else if (hoursAgo <= 72) {
            totalScore += 20;
          }
        } catch (_) {}
      }
    }

    return totalScore.clamp(0, 1000).toInt();
  }

  bool _isContractType(String tag) {
    return const {
      'cdd',
      'cdi',
      'stage',
      'freelance',
      'intérim',
      'alternance',
    }.contains(TagNormalizer.normalizeKey(tag));
  }

  /// Vérifie si un texte contient un mot ou pattern, avec gestion des frontières de mots
  /// pour les mots courts afin d'éviter les faux positifs (ex: 'it' dans 'cuisine', ou 'tech' dans 'technicien').
  bool _matchWord(String text, String word) {
    final textLower = text.toLowerCase();
    final wordLower = TagNormalizer.normalizeKey(word);

    if (wordLower.isEmpty) return false;

    if (wordLower.length <= 4) {
      // Pour les mots courts et acronymes (it, rh, cdd, btp, tech, data), on exige des frontières de mots via Regex
      // \b assure que le mot est entouré d'espaces, ponctuation ou début/fin de ligne.
      final escaped = RegExp.escape(wordLower);
      return RegExp('\\b$escaped\\b', caseSensitive: false).hasMatch(textLower);
    }

    // Pour les mots longs, on accepte le contains standard pour plus de souplesse
    return textLower.contains(wordLower);
  }

  bool get _hasCv {
    if (_cvUrl == null) return false;
    final cleanUrl = _cvUrl!.trim().toLowerCase();
    return cleanUrl.isNotEmpty && cleanUrl != 'null' && cleanUrl != 'undefined';
  }

  bool _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) {
    // Réinitialiser la direction du drag
    setState(() {
      _dragDirection = CardSwiperDirection.none;
    });

    // BLOCAGE PHYSIQUE STRICT : Si pas swipes illimités et limite dynamique atteinte
    // On bloque TOUT mouvement (Gauche ou Droite)
    if (!_hasUnlimitedSwipes && _swipeCount >= VersionService.swipeLimit) {
      _showPremiumLimitDialog();
      return false; // Bloque physiquement la carte
    }

    if (direction == CardSwiperDirection.right) {
      // Bloquer le Swipe Droite si l'utilisateur n'a pas mis de CV
      if (!_hasCv) {
        _showMissingCvDialog();
        return false; // Renvoie la carte au centre
      }

      _handleSwipe(previousIndex, 'right');
    } else if (direction == CardSwiperDirection.left) {
      _handleSwipe(previousIndex, 'left');
    }

    // Mise à jour de l'index de la carte uniquement si le swipe est validé
    setState(() {
      _currentCardIndex = currentIndex ?? 0;
    });
    return true;
  }

  void _handleSwipe(int index, String direction) {
    if (index < 0 || index >= _jobs.length) return; // Sécurité anti-crash
    final job = _jobs[index];
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // MISE À JOUR UI IMMÉDIATE (pas d'attente réseau)
    setState(() {
      _swipeCount++;
    });

    // Mettre à jour le cache local des swiped IDs et du compteur (pas de requête réseau)
    final jobId = job['id']?.toString();
    if (jobId != null) {
      _cachedSwipedIds.add(jobId);
      // Sauvegarder en arrière-plan (fire-and-forget)
      unawaited(
        LocalCache.save(LocalCache.swipedIdsKey, _cachedSwipedIds.toList()),
      );
      unawaited(LocalCache.save(LocalCache.swipeCountKey, _swipeCount));
    }

    // Charger le batch suivant si on est bas en stock
    if (_jobs.length - (index + 1) <= 5) {
      debugPrint(
        '*** [PAGINATION] Stock bas (${_jobs.length - (index + 1)} restants), chargement du batch suivant... ***',
      );
      _loadNextBatch();
    }

    // Vérifier si on doit proposer de noter l'application
    _checkAndPromptRating();

    // TOUTES les opérations DB en arrière-plan (fire-and-forget)
    _performSwipeDbOps(userId, job, direction);
  }

  /// Opérations DB du swipe en arrière-plan — ne bloque jamais l'UI
  Future<void> _performSwipeDbOps(
    String userId,
    Map<String, dynamic> job,
    String direction,
  ) async {
    try {
      // 1. Enregistrer l'action dans le log global (fire-and-forget)
      unawaited(
        _supabase
            .from('swipes_log')
            .insert({
              'user_id': userId,
              'job_id': job['id'],
              'direction': direction,
            })
            .catchError((e) {
              debugPrint('Erreur log swipe: $e');
              return null;
            }),
      );

      // 1.5 Mettre à jour le compteur de swipes quotidien par pallier (tous les 5 swipes, ou si limite atteinte)
      final reachedLimit =
          !_isPremium && _swipeCount >= VersionService.swipeLimit;
      final isInterval = _swipeCount % 5 == 0;
      if (isInterval || reachedLimit) {
        _lastWrittenSwipeCount = _swipeCount;
        final today = DateTime.now().toIso8601String().substring(0, 10);
        unawaited(
          _supabase
              .from('profiles')
              .update({
                'daily_swipe_count': _swipeCount,
                'last_swipe_date': today,
              })
              .eq('id', userId)
              .catchError((e) {
                debugPrint('Erreur mise à jour daily_swipe_count en DB: $e');
                return null;
              }),
        );
      }

      // 2. Traitement spécifique si c'est un swipe DROITE (postulation)
      if (direction == 'right') {
        debugPrint('*** [DIAGNOSTIC] DÉBUT SWIPE DROITE DÉTECTÉ ***');

        // Demande de consentement explicite au candidat pour partager sa Fiche & Parcours (enregistré définitivement une fois accepté)
        final jobTitle = job['job_title'] ?? 'cette offre';
        final bool userConsented = await _checkOrRequestApplyConsent(
          context,
          jobTitle,
        );
        if (!userConsented) {
          debugPrint('*** [DIAGNOSTIC] SWIPE ANNULÉ PAR LE CANDIDAT ***');
          return;
        }

        // Signaler à l'écran des matches de s'actualiser
        MatchNotifier.notifyNewMatch();

        debugPrint('*** [DIAGNOSTIC] URL CV: $_cvUrl ***');

        final whatsapp = job['whatsapp_number'];
        final email = job['contact_email'];
        final appLink = job['application_link'];

        final hasEmail = email != null && email.toString().trim().isNotEmpty;
        final hasWhatsapp =
            whatsapp != null && whatsapp.toString().trim().isNotEmpty;
        final hasLink = appLink != null && appLink.toString().trim().isNotEmpty;

        // Priorité des redirections sur Match (Swipe Right) :
        if (hasEmail) {
          // L'email est prioritaire.
          if (_cvUrl != null && _cvUrl!.isNotEmpty) {
            _enqueueEmail(job);

            if (mounted) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Candidature enregistrée pour ${job['job_title']} — email en cours d\'envoi...',
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(milliseconds: 1500),
                ),
              );
            }
          }
        } else if (hasWhatsapp) {
          // Le numéro prend le relais uniquement si pas d'email
          _showWhatsAppRedirect(
            job['job_title'] ?? 'ce poste',
            job['company_name'] ?? '',
            whatsapp.toString(),
            job['id'].toString(),
          );
        } else if (hasLink) {
          // Le lien prend le relais uniquement si ni email ni numéro
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Postulé par lien externe'),
                backgroundColor: Colors.blue,
                duration: Duration(milliseconds: 1500),
              ),
            );
          }
          _showApplicationLinkRedirect(
            job['job_title'] ?? 'ce poste',
            appLink.toString(),
            job['id'].toString(),
          );
        } else if (mounted) {
          // Aucun moyen de contact précis (Fallback)
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil envoyé au recruteur'),
              backgroundColor: Colors.green,
              duration: Duration(milliseconds: 1500),
            ),
          );
        }

        // Proposer l'activation de la visibilité recruteur si désactivée sur le profil
        _checkAndPromptRecruiterVisibility();
      }
    } catch (e) {
      debugPrint('Erreur lors du swipe: $e');
      if (e.toString().contains('Daily free swipe limit')) {
        _controller.undo(); // Ramène la carte à l'écran
        setState(
          () => _swipeCount = VersionService.swipeLimit,
        ); // Resynchronise le compteur local de force
        if (mounted) _showPremiumLimitDialog();
      }
    }
  }

  /// Vérifie si la visibilité recruteur est désactivée et affiche le modal d'activation
  Future<void> _checkAndPromptRecruiterVisibility() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final res = await _supabase
          .from('profiles')
          .select('is_visible_to_recruiters')
          .eq('id', user.id)
          .maybeSingle();

      final bool isVisible = res?['is_visible_to_recruiters'] == true;
      if (!isVisible && mounted) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _showRecruiterVisibilityModal(context);
        });
      }
    } catch (e) {
      debugPrint('Error checking recruiter visibility: $e');
    }
  }

  /// Affiche le modal incitant à activer la visibilité par les recruteurs
  void _showRecruiterVisibilityModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 28.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 20.h),

              // Glowing Blue Icon Badge
              Container(
                width: 64.r,
                height: 64.r,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.visibility_rounded,
                  color: Colors.white,
                  size: 32.r,
                ),
              ),
              SizedBox(height: 18.h),

              // Title
              Text(
                'Multipliez vos opportunités !',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 10.h),

              // Body text
              Text(
                'Votre visibilité par les recruteurs est actuellement désactivée. Activez-la dans votre profil pour permettre aux entreprises de vous contacter directement !',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: const Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              SizedBox(height: 24.h),

              // Primary Action: Redirect to profile & highlight toggle
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ProfileNotifier.navigateToProfileWithVisibilityHighlight();
                  },
                  icon: const Icon(Icons.person_pin_rounded, size: 20),
                  label: const Text('Activer dans mon Profil'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    elevation: 0,
                    textStyle: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8.h),

              // Cancel button
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Plus tard',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _hasAcceptedApplyConsentMemory = false;

  /// Vérifie si le candidat a déjà accepté le consentement de partage de profil.
  /// Si oui, le dialogue ne réapparaît plus jamais (mémorisé dans SharedPreferences).
  Future<bool> _checkOrRequestApplyConsent(
    BuildContext context,
    String jobTitle,
  ) async {
    if (_hasAcceptedApplyConsentMemory) return true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyAccepted =
          prefs.getBool('has_accepted_apply_consent') ?? false;
      if (alreadyAccepted) {
        _hasAcceptedApplyConsentMemory = true;
        return true;
      }
    } catch (e) {
      debugPrint('Error reading apply consent: $e');
    }

    if (!mounted) return false;
    final accepted = await _showApplicationConsentDialog(context, jobTitle);
    if (accepted) {
      _hasAcceptedApplyConsentMemory = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_accepted_apply_consent', true);
      } catch (e) {
        debugPrint('Error saving apply consent: $e');
      }
    }
    return accepted;
  }

  Future<bool> _showApplicationConsentDialog(
    BuildContext context,
    String jobTitle,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(22.r),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Icon Badge
                Container(
                  width: 56.r,
                  height: 56.r,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: const Color(0xFF16A34A),
                    size: 26.r,
                  ),
                ),
                SizedBox(height: 16.h),

                // Title
                Text(
                  'Postuler à l\'offre',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 12.h),

                // Consent Text
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF475569),
                      height: 1.5,
                      fontFamily: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.fontFamily,
                    ),
                    children: [
                      const TextSpan(text: 'En postulant à '),
                      TextSpan(
                        text: '"$jobTitle"',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const TextSpan(
                        text:
                            ', acceptez-vous de partager votre Fiche & Parcours (Compétences, Diplômes, Expériences) avec le recruteur pour cette offre ?',
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),

                // Security info banner
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: const Color(0xFF16A34A),
                        size: 18.r,
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          'Vos données restent protégées et partagées uniquement pour cette candidature.',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF15803D),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 22.h),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'Annuler',
                          style: TextStyle(
                            color: const Color(0xFF64748B),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 16.r),
                            SizedBox(width: 6.w),
                            Text(
                              'Accepter & Postuler',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  /// Ajoute un job à la file d'attente d'envoi d'email
  void _enqueueEmail(Map<String, dynamic> job) {
    _emailQueue.add(job);
    debugPrint(
      '*** [QUEUE] Email ajouté à la file. Taille: ${_emailQueue.length} ***',
    );

    // Lancer le traitement de la file si pas déjà en cours
    if (!_isProcessingQueue) {
      _processEmailQueue();
    }
  }

  /// Traite la file d'attente d'envoi d'email un par un avec délai
  Future<void> _processEmailQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    while (_emailQueue.isNotEmpty) {
      final job = _emailQueue.removeAt(0);

      try {
        final response = await _supabase.functions.invoke(
          'apply-to-job',
          body: {
            'jobTitle': job['job_title'],
            'jobCompany': job['company_name'],
            'jobContactEmail': job['contact_email'],
            'cvUrl': job['adapted_cv_url'] ?? _cvUrl,
            'userName': _fullName,
            'userSexe': _sexe,
            'message': null,
            'requiresCoverLetter': job['requires_cover_letter'] ?? false,
            'coverLetterInstructions': job['cover_letter_instructions'],
            'jobDescription': job['description'],
          },
        );

        debugPrint(
          '*** [QUEUE] RÉPONSE SERVEUR: ${response.status} - ${response.data} ***',
        );

        if (response.status == 200) {
          debugPrint(
            '*** [QUEUE] ✅ Email envoyé avec succès pour: ${job['job_title']} ***',
          );
        } else {
          debugPrint(
            '*** [QUEUE] ❌ Erreur serveur pour: ${job['job_title']} - ${response.data} ***',
          );
        }
      } catch (funcErr) {
        debugPrint(
          '*** [QUEUE] ❌ ERREUR CRITIQUE pour ${job['job_title']}: $funcErr ***',
        );
      }

      // Délai entre chaque envoi pour éviter le rate-limiting de Resend
      if (_emailQueue.isNotEmpty) {
        debugPrint('*** [QUEUE] Attente 2s avant le prochain envoi... ***');
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    _isProcessingQueue = false;
    debugPrint(
      '*** [QUEUE] File d\'attente vidée. Tous les emails envoyés. ***',
    );
  }

  void _showMissingCvDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        title: Row(
          children: [
            const Icon(Icons.description_outlined, color: Color(0xFFF97316)),
            SizedBox(width: 10.w),
            const Text(
              'CV Manquant',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Afin de postuler aux offres, vous devez d\'abord téléverser votre CV dans l\'onglet de votre profil.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Compris',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showPremiumFeatureDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        title: Row(
          children: [
            const Icon(Icons.star, color: Color(0xFFF97316)),
            SizedBox(width: 10.w),
            Text(
              VersionService.showPremium
                  ? 'Fonction Premium'
                  : 'Bientôt disponible',
            ),
          ],
        ),
        content: Text(
          VersionService.showPremium
              ? 'La fonctionnalité "$feature" est réservée aux membres Premium.\n\nPassez au forfait illimité pour en profiter !'
              : 'La fonctionnalité "$feature" sera bientôt disponible pour tous !',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Plus tard',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          if (VersionService.showPremium)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/premium').then((_) {
                  if (mounted) {
                    setState(() => _isLoading = true);
                    _loadData(forceRefresh: true);
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Passer Premium',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  void _showPremiumLimitDialog() {
    // Calculer le temps restant avant minuit
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final remaining = midnight.difference(now);

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        title: Row(
          children: [
            const Icon(Icons.lock_clock, color: Color(0xFFF97316)),
            SizedBox(width: 10.w),
            Text(VersionService.swipeLimitTitle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(VersionService.formattedSwipeMessage()),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Nouveaux swipes dans $hours\h $minutes\min',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            if (VersionService.showPremium) ...[
              const Text(
                'Ou passez au illimité maintenant pour ne rater aucun Djorssi !',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Plus tard',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          if (VersionService.showPremium)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/premium').then((_) {
                  if (mounted) {
                    setState(() => _isLoading = true);
                    _loadData(forceRefresh: true);
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Passer Premium',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  /// Extrait les numéros de téléphone individuels d'une chaîne (numéros collés ou séparés)
  List<String> _extractPhoneNumbers(String raw) {
    final List<String> numbers = [];
    final String cleaned = raw.replaceAll(RegExp(r'[\s\-\.\(\)]+'), '');
    final Iterable<Match> digitBlocks = RegExp(r'\d+').allMatches(cleaned);

    for (final block in digitBlocks) {
      final String digits = block.group(0)!;
      String remaining = digits;

      while (remaining.isNotEmpty) {
        if (remaining.startsWith('225')) {
          if (remaining.length >= 13) {
            numbers.add(remaining.substring(0, 13));
            remaining = remaining.substring(13);
          } else if (remaining.length >= 11) {
            numbers.add(remaining.substring(0, 11));
            remaining = remaining.substring(11);
          } else {
            if (remaining.length >= 8) {
              numbers.add(remaining);
            }
            remaining = '';
          }
        } else {
          if (remaining.length >= 10) {
            numbers.add(remaining.substring(0, 10));
            remaining = remaining.substring(10);
          } else if (remaining.length >= 8) {
            numbers.add(remaining);
            remaining = '';
          } else {
            remaining = '';
          }
        }
      }
    }
    return numbers;
  }

  void _showWhatsAppRedirect(
    String jobTitle,
    String companyName,
    String phoneNumber,
    String jobId,
  ) {
    if (!mounted) return;

    // Extraire tous les numéros individuels
    final List<String> numbers = _extractPhoneNumbers(phoneNumber);

    if (numbers.isEmpty) return; // Aucun numéro de téléphone détecté

    // On prend le PREMIER numéro trouvé pour WhatsApp
    final String firstNum = numbers.first;

    // Ajouter le code pays CIV si manquant (8 ou 10 chiffres sans indicatif)
    final finalPhone = firstNum.length <= 10 ? '225$firstNum' : firstNum;

    // Formater les numéros pour l'affichage
    final String displayNumbers = numbers.join(' / ');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Row(
          children: [
            const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366)),
            SizedBox(width: 10.w),
            const Expanded(child: Text('Postuler via WhatsApp')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prêt à postuler ?',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            Text(
              "L'application va ouvrir WhatsApp avec le premier numéro du recruteur. N'oubliez pas de joindre votre CV !",
              style: TextStyle(fontSize: 13.sp),
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: const Color(0xFF25D366).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone, size: 16.r, color: const Color(0xFF25D366)),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      displayNumbers,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF166534),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Plus tard',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final cleanCompany = companyName.trim().toLowerCase();
              final isCompanyKnown =
                  companyName.trim().isNotEmpty &&
                  cleanCompany != 'inconnu' &&
                  cleanCompany != 'inconnue' &&
                  cleanCompany != 'non précisé' &&
                  cleanCompany != 'non precise' &&
                  cleanCompany != 'non spécifié' &&
                  cleanCompany != 'non specifie' &&
                  cleanCompany != 'non renseigné' &&
                  cleanCompany != 'non renseigne';

              final e = (_sexe == 'Femme') ? 'e' : '';
              final interestText = (_sexe == 'Femme')
                  ? 'intéressée'
                  : 'intéressé';

              // Liste de formulations de messages pour WhatsApp (10 templates)
              final List<String> messageTemplates = isCompanyKnown
                  ? [
                      "Bonjour, je suis très $interestText par le poste de $jobTitle au sein de $companyName vu sur Djorssi-Match. Veuillez trouver mon CV ci-joint.",
                      "Bonjour, j'ai vu votre offre pour le poste de $jobTitle chez $companyName sur Djorssi-Match et je suis très $interestText. Mon CV est en pièce jointe.",
                      "Bonjour, je me permets de vous contacter concernant le poste de $jobTitle au sein de $companyName publié sur Djorssi-Match. Mon profil correspondant à vos critères, je vous joins mon CV.",
                      "Bonjour, $interestText$e par le poste de $jobTitle chez $companyName vu sur Djorssi-Match, je vous transmets mon CV ci-joint pour l'étude de ma candidature.",
                      "Bonjour, je souhaite postuler à l'offre de $jobTitle au sein de $companyName parue sur Djorssi-Match. Vous trouverez mon CV ci-joint.",
                      "Bonjour, c'est avec un grand intérêt que je vous soumets mon CV ci-joint pour le poste de $jobTitle chez $companyName vu sur Djorssi-Match.",
                      "Bonjour, actuellement à la recherche de nouvelles opportunités, je postule pour le poste de $jobTitle au sein de $companyName (vu sur Djorssi-Match). Mon CV est joint.",
                      "Bonjour, je vous contacte suite à votre annonce sur Djorssi-Match pour le poste de $jobTitle chez $companyName. Mon CV est ci-joint pour votre étude.",
                      "Bonjour, motivé$e et disponible, je souhaite proposer ma candidature pour le poste de $jobTitle au sein de $companyName vu sur Djorssi-Match. Mon CV est joint.",
                      "Bonjour, suite à votre publication sur Djorssi-Match, je serais ravi$e d'échanger avec vous sur le poste de $jobTitle chez $companyName. Vous trouverez mon CV ci-joint.",
                    ]
                  : [
                      "Bonjour, je suis très $interestText par le poste de $jobTitle vu sur Djorssi-Match. Veuillez trouver mon CV ci-joint.",
                      "Bonjour, j'ai vu votre offre pour le poste de $jobTitle sur Djorssi-Match et je suis très $interestText. Mon CV est en pièce jointe.",
                      "Bonjour, je me permets de vous contacter concernant le poste de $jobTitle publié sur Djorssi-Match. Mon profil correspondant à vos critères, je vous joins mon CV.",
                      "Bonjour, $interestText$e par le poste de $jobTitle vu sur Djorssi-Match, je vous transmets mon CV ci-joint pour l'étude de ma candidature.",
                      "Bonjour, je souhaite postuler à l'offre de $jobTitle parue sur Djorssi-Match. Vous trouverez mon CV ci-joint.",
                      "Bonjour, c'est avec un grand intérêt que je vous soumets mon CV ci-joint pour le poste de $jobTitle vu sur Djorssi-Match.",
                      "Bonjour, actuellement à la recherche de nouvelles opportunités, je postule pour le poste de $jobTitle (vu sur Djorssi-Match). Mon CV est joint.",
                      "Bonjour, je vous contacte suite à votre annonce sur Djorssi-Match pour le poste de $jobTitle. Mon CV est ci-joint pour votre étude.",
                      "Bonjour, motivé$e et disponible, je souhaite proposer ma candidature pour le poste de $jobTitle vu sur Djorssi-Match. Mon CV est joint.",
                      "Bonjour, suite à votre publication sur Djorssi-Match, je serais ravi$e d'échanger avec vous sur le poste de $jobTitle. Vous trouverez mon CV ci-joint.",
                    ];

              // Sélectionner un index basé sur la milliseconde actuelle pour simuler un choix aléatoire simple
              final randomIndex =
                  DateTime.now().millisecond % messageTemplates.length;
              final textMessage = messageTemplates[randomIndex];

              final message = Uri.encodeComponent(textMessage);
              final whatsappAppUrl = Uri.parse(
                "whatsapp://send?phone=$finalPhone&text=$message",
              );
              final webUrl = Uri.parse(
                "https://wa.me/$finalPhone?text=$message",
              );

              try {
                if (await canLaunchUrl(whatsappAppUrl)) {
                  await launchUrl(
                    whatsappAppUrl,
                    mode: LaunchMode.externalApplication,
                  );
                } else if (await canLaunchUrl(webUrl)) {
                  await launchUrl(webUrl, mode: LaunchMode.externalApplication);
                } else {
                  await launchUrl(
                    webUrl,
                    mode: LaunchMode.externalNonBrowserApplication,
                  );
                }
              } catch (e) {
                debugPrint(
                  'Primary WhatsApp launch failed, trying webUrl fallback: $e',
                );
                try {
                  await launchUrl(webUrl, mode: LaunchMode.externalApplication);
                } catch (e2) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Impossible d'ouvrir WhatsApp sur cet appareil.",
                        ),
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: const Text(
              'Envoyer mon CV',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showApplicationLinkRedirect(
    String jobTitle,
    String urlString,
    String jobId,
  ) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Row(
          children: [
            const Icon(Icons.open_in_new_rounded, color: Color(0xFFF97316)),
            SizedBox(width: 10.w),
            const Expanded(child: Text('Postuler en ligne')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cette offre nécessite de postuler sur un site externe.',
              style: TextStyle(fontSize: 14.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              "Voulez-vous ouvrir le lien de candidature ?",
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Plus tard',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final url = Uri.parse(urlString);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: const Text(
              'Ouvrir le lien',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFF97316)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Djorssi-Match',
          style: TextStyle(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 24.sp,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed: () async {
                  await context.push('/notifications');
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(
                    'last_notifications_view',
                    DateTime.now().toIso8601String(),
                  );
                  setState(() => _hasUnreadNotifications = false);
                },
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Color(0xFF0F172A),
                  size: 26,
                ),
              ),
              if (_hasUnreadNotifications)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 8,
                      minHeight: 8,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(width: 8.w),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFFE2E8F0), // Ligne de séparation douce
            height: 1.0,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _isLoading = true);
          await _loadData(forceRefresh: true);
        },
        color: const Color(0xFFF97316),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ListView(
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: constraints.maxHeight,
                  child: _jobs.isEmpty
                      ? _buildEmptyState()
                      : Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 4.h,
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 600,
                                    ),
                                    child: CardSwiper(
                                      key: ValueKey(_swiperKey),
                                      controller: _controller,
                                      cardsCount: _jobs.length,
                                      onSwipe: _onSwipe,
                                      onSwipeDirectionChange:
                                          (
                                            horizontalDirection,
                                            verticalDirection,
                                          ) {
                                            setState(() {
                                              _dragDirection =
                                                  horizontalDirection;
                                            });
                                          },
                                      numberOfCardsDisplayed: _jobs.isEmpty
                                          ? 1
                                          : (_jobs.length >= 3
                                                ? 3
                                                : _jobs.length),
                                      backCardOffset: const Offset(0, 40),
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      padding: EdgeInsets.zero,
                                      scale: 0.9,
                                      maxAngle: 30,
                                      threshold: 40,
                                      isLoop: false,
                                      onEnd: () {
                                        setState(() {
                                          _jobs.clear();
                                          _dragDirection =
                                              CardSwiperDirection.none;
                                        });
                                      },
                                      cardBuilder:
                                          (
                                            context,
                                            index,
                                            horizontalThresholdPercent,
                                            verticalThresholdPercent,
                                          ) {
                                            final job = _jobs[index];
                                            final jobId =
                                                job['id']?.toString() ?? '';
                                            final matchScore =
                                                _matchScoreCache[jobId] ?? 0;
                                            return Stack(
                                              children: [
                                                DjossiSwipeCard(
                                                  title:
                                                      job['job_title'] ??
                                                      'Inconnu',
                                                  company:
                                                      job['company_name'] ??
                                                      'Inconnu',
                                                  salary:
                                                      job['salary_range'] ??
                                                      'À négocier',
                                                  location:
                                                      job['location'] ??
                                                      'Abidjan',
                                                  requiredLevel:
                                                      job['required_level'],
                                                  experience: job['experience'],
                                                  contactEmail:
                                                      job['contact_email'],
                                                  whatsappNumber:
                                                      job['whatsapp_number'],
                                                  specialty: job['specialty'],
                                                  contractType:
                                                      job['contract_type'],
                                                  description:
                                                      job['description'],
                                                  isVerified:
                                                      job['is_ai_verified'] ??
                                                      false,
                                                  tags: List<String>.from(
                                                    job['tags'] ?? [],
                                                  ),
                                                  deadline: _getDisplayDeadline(
                                                    job,
                                                  ),
                                                  applicationLink:
                                                      job['application_link'],
                                                  requiresCoverLetter:
                                                      job['requires_cover_letter'] ??
                                                      false,
                                                  coverLetterInstructions:
                                                      job['cover_letter_instructions'],
                                                ),
                                                if (matchScore > 0)
                                                  Positioned(
                                                    top: 12.h,
                                                    right: 12.w,
                                                    child: _buildMatchBadge(
                                                      matchScore,
                                                    ),
                                                  ),
                                              ],
                                            );
                                          },
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 32.h),
                              _buildActionButtons(),
                              SizedBox(height: 8.h),
                            ],
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome,
              size: 70.r,
              color: const Color(0xFFF97316),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'Beau travail ! 🚀',
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.w),
            child: Text(
              'Vous avez parcouru toutes les offres correspondant à vos critères actuels. De nouvelles opportunités sont publiées chaque jour !',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.sp,
                color: const Color(0xFF475569), // Slate 600
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: 40.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.w),
            child: Column(
              children: [
                Text(
                  'Envie de découvrir plus ?',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B), // Slate 500
                  ),
                ),
                SizedBox(height: 16.h),
                ElevatedButton(
                  onPressed: () => context.go('/?tab=profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 56.h),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: Text(
                    'Modifier mes secteurs d\'intérêt',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _isLoading = true);
                    _loadData(forceRefresh: true);
                  },
                  icon: const Icon(Icons.refresh, size: 20),
                  label: Text(
                    'Lancer un nouveau scan',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFF97316),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchBadge(int matchScore) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: matchScore >= 50
            ? const Color(0xFF22C55E)
            : const Color(0xFFF97316),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, color: Colors.white, size: 14.r),
          SizedBox(width: 4.w),
          Text(
            'Match ${matchScore > 100 ? 100 : matchScore}%',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUndo() async {
    if (!VersionService.featRewind) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le retour en arrière est actuellement désactivé.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (!_isPremium && VersionService.showPremium) {
      _showPremiumFeatureDialog('Retour en arrière');
      return;
    }

    // Dans CardSwiper, l'undo ramène la carte précédente
    _controller.undo();

    setState(() {
      if (_swipeCount > 0) _swipeCount--;
      if (_currentCardIndex > 0) _currentCardIndex--;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        // Optionnel: On pourrait supprimer le log en DB
      }
    } catch (e) {
      debugPrint('Erreur undo DB: $e');
    }
  }

  void _shareJob(Map<String, dynamic> job) {
    final String title = job['job_title'] ?? 'Inconnu';
    final String company = job['company_name'] ?? 'Non précisé';
    final String location = job['location'] ?? 'Abidjan';
    final String salary = job['salary_range'] ?? 'À négocier';
    final String? requiredLevel = job['required_level'];
    final String? description = job['description'];

    final String shareText =
        '''
📢 Offre d'emploi : $title chez $company

📍 Lieu : $location
💰 Salaire : $salary
🎓 Niveau requis : ${requiredLevel ?? 'Non spécifié'}

📝 Description du poste :
${description ?? 'Aucune description fournie.'}

🔗 Retrouvez plus d'offres et postulez sur Djorssi-Match !
''';

    Share.share(shareText, subject: 'Offre d\'emploi : $title');
  }

  Widget _buildActionButtons() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              Icons.close_rounded,
              Colors.red,
              () {
                if (!_hasUnlimitedSwipes &&
                    _swipeCount >= VersionService.swipeLimit) {
                  _showPremiumLimitDialog();
                  return;
                }
                _controller.swipe(CardSwiperDirection.left);
              },
              isHighlighted: _dragDirection == CardSwiperDirection.left,
            ),
            _buildActionButton(
              Icons.replay_rounded,
              (_isPremium && VersionService.showPremium)
                  ? const Color(0xFFF59E0B)
                  : Colors.grey,
              _handleUndo,
              isMini: true,
              locked: false, // Cadenas retiré à la demande de l'utilisateur
            ),
            _buildActionButton(
              Icons.auto_awesome,
              VersionService.aiAdaptEnabled
                  ? const Color(0xFF8B5CF6)
                  : const Color(0xFFCBD5E1),
              _onAdaptCvPressed,
              isMini: true,
              enabled: VersionService.aiAdaptEnabled,
            ),
            _buildActionButton(
              Icons.favorite_rounded,
              Colors.green,
              () {
                if (!_hasUnlimitedSwipes &&
                    _swipeCount >= VersionService.swipeLimit) {
                  _showPremiumLimitDialog();
                  return;
                }
                if (!_hasCv) {
                  _showMissingCvDialog();
                  return;
                }
                _controller.swipe(CardSwiperDirection.right);
              },
              isHighlighted: _dragDirection == CardSwiperDirection.right,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    bool isMini = false,
    bool locked = false,
    bool isHighlighted = false,
    bool enabled = true,
  }) {
    final size = isMini ? 55.r : 70.r;
    final iconSize = isMini ? 24.r : 32.r;
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          width: isHighlighted ? size * 1.15 : size,
          height: isHighlighted ? size * 1.15 : size,
          decoration: BoxDecoration(
            color: enabled
                ? (isHighlighted ? color : Colors.white)
                : const Color(0xFFF8FAFC),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (enabled ? color : const Color(0xFFCBD5E1)).withOpacity(
                  isHighlighted ? 0.4 : 0.2,
                ),
                spreadRadius: isHighlighted ? 6.r : 2.r,
                blurRadius: isHighlighted ? 15.r : 10.r,
                offset: Offset(0, 4.h),
              ),
            ],
            border:
                (_isPremium && VersionService.showPremium) &&
                    !isMini &&
                    color == Colors.green
                ? Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.5),
                    width: 2,
                  )
                : null,
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: enabled
                  ? (isHighlighted ? Colors.white : color)
                  : const Color(0xFF94A3B8),
              size: isHighlighted ? iconSize * 1.1 : iconSize,
            ),
            onPressed: enabled ? onPressed : null,
          ),
        ),
        if (locked)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(4.r),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock,
                color: const Color(0xFFF59E0B),
                size: 12.r,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _checkAndPromptRating() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int swipeTotal = (prefs.getInt('swipe_total_count') ?? 0) + 1;
      await prefs.setInt('swipe_total_count', swipeTotal);

      // Proposer tous les 25 swipes (environ 2-3 sessions)
      if (swipeTotal > 0 && swipeTotal % 25 == 0) {
        _showRatingDialog();
      }
    } catch (e) {
      debugPrint('Erreur check rating: $e');
    }
  }

  void _showRatingDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: const Row(
          children: [
            Icon(Icons.star_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Text('Aidez-nous !'),
          ],
        ),
        content: const Text(
          'Vous semblez apprécier Djorssi Match ! Pourriez-vous nous donner 5 étoiles ? Cela aide d\'autres personnes à trouver un emploi.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Plus tard',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openStoreForRating();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: const Text(
              'Noter maintenant',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openStoreForRating() async {
    final InAppReview inAppReview = InAppReview.instance;
    try {
      await inAppReview.openStoreListing(appStoreId: '6767549287');
    } catch (e) {
      debugPrint('Erreur ouverture store: $e');
    }
  }

  Future<void> _onAdaptCvPressed() async {
    if (!VersionService.aiAdaptEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Le générateur d'adaptation de CV est temporairement désactivé.",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_jobs.isEmpty || _currentCardIndex >= _jobs.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Aucune offre disponible à adapter."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final job = _jobs[_currentCardIndex];

    // ── Vérification du quota d'adaptation IA ──
    final quotaResult = await CvQuotaService.canAdaptCv();
    if (!quotaResult.allowed) {
      if (quotaResult.isFeatureDisabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                quotaResult.blockedMessage ??
                    "Le générateur d'adaptation de CV est temporairement désactivé.",
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      if (mounted) {
        final paid = await CvPaywallSheet.show(
          context,
          PaymentReason.aiAdaptation,
        );
        if (!paid) return; // L'utilisateur a annulé
      }
    }

    // ── Premium animated loader ──
    final hasProfilePdf =
        _cvUrl != null &&
        _cvUrl!.trim().isNotEmpty &&
        _cvUrl != 'null' &&
        _cvUrl != 'undefined';

    if (hasProfilePdf) {
      // Priorité 1 : Toujours adapter le CV PDF du profil candidat
      _importProfilePdfAndAdapt(job);
      return;
    }

    // Priorité 2 : Si pas de PDF sur le profil, utiliser le CV existant
    _showAiLoader(context, "Chargement de votre CV...");
    try {
      final cvs = await CvStorageService.loadUserCvs();
      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog
      }

      if (cvs.isNotEmpty) {
        _runCvAdaptation(cvs.first, job);
      } else {
        if (mounted) _showNoCvDialog();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur de chargement de votre CV : $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Importe le PDF du profil et lance l'adaptation IA
  Future<void> _importProfilePdfAndAdapt(Map<String, dynamic> job) async {
    _showAiLoader(context, "Importation de votre CV du profil...");
    try {
      if (_cvUrl != null &&
          _cvUrl!.trim().isNotEmpty &&
          _cvUrl != 'null' &&
          _cvUrl != 'undefined') {
        final response = await http
            .get(Uri.parse(_cvUrl!))
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final pdfBytes = response.bodyBytes;
          final rawText = CvAiImportService.extractTextFromPdf(pdfBytes);

          if (rawText.isNotEmpty) {
            final parsedCv = await CvAiImportService.analyzeWithMistral(
              rawText,
            );
            final savedCv = await CvStorageService.saveCv(
              parsedCv,
              bypassQuota: true,
            );

            if (mounted) {
              Navigator.pop(context); // Dismiss loading dialog
              _runCvAdaptation(savedCv, job);
            }
            return;
          }
        }
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Impossible de lire le fichier PDF de votre profil."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur d'importation du PDF : $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showNoCvDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "Aucun CV trouvé",
          style: TextStyle(fontFamily: 'Outfit'),
        ),
        content: const Text(
          "Vous devez créer ou importer un CV dans l'onglet 'Mon CV' avant de pouvoir l'adapter à une offre d'emploi.",
          style: TextStyle(fontFamily: 'Outfit'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Fermer", style: TextStyle(fontFamily: 'Outfit')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/?tab=cv');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
            ),
            child: const Text(
              "Créer un CV",
              style: TextStyle(fontFamily: 'Outfit'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runCvAdaptation(
    CvModel baseCv,
    Map<String, dynamic> job,
  ) async {
    if (!VersionService.aiAdaptEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Le générateur d'adaptation de CV est temporairement désactivé.",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    bool isCancelled = false;
    // Premium animated loader
    _showAiLoader(
      context,
      "L'IA analyse l'offre et adapte votre CV...",
      onCancel: () {
        isCancelled = true;
      },
    );

    try {
      final adaptedCv = await CvAiImportService.adaptCv(
        sourceCv: baseCv,
        jobTitle: job['job_title'] ?? '',
        jobCompany: job['company_name'] ?? '',
        jobDescription: job['description'] ?? '',
      );

      if (isCancelled || !mounted) return;

      // Consommer un crédit d'adaptation si l'essai gratuit n'est pas illimité
      if (!VersionService.isAiAdaptTrialRunning) {
        await CvQuotaService.consumeAdaptationCredit();
      }
      await CvQuotaService.recordAdaptation();

      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        _showCvReviewSheet(baseCv, adaptedCv, job);
      }
    } catch (e) {
      if (isCancelled || !mounted) return;
      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur d'adaptation : $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCvReviewSheet(
    CvModel baseCv,
    CvModel adaptedCv,
    Map<String, dynamic> job,
  ) {
    CvModel currentAdaptedCv = adaptedCv;
    int selectedTab = 0; // 0 for Modifications, 1 for PDF Preview

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              padding: EdgeInsets.fromLTRB(
                16.w,
                16.h,
                16.w,
                MediaQuery.of(context).viewInsets.bottom + 16.h,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 5.h,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(100.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome, color: Color(0xFFF97316)),
                      SizedBox(width: 8.w),
                      Text(
                        "Revoir les modifications",
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Premium sliding segmented control
                  Center(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      padding: EdgeInsets.all(2.r),
                      child: CupertinoSlidingSegmentedControl<int>(
                        groupValue: selectedTab,
                        backgroundColor: Colors.transparent,
                        thumbColor: Colors.white,
                        children: {
                          0: Container(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.compare_arrows_rounded,
                                  size: 15.sp,
                                  color: selectedTab == 0
                                      ? const Color(0xFFF97316)
                                      : Colors.grey[600],
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  "Modifs IA",
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.sp,
                                    color: selectedTab == 0
                                        ? const Color(0xFFF97316)
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          1: Container(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_outline_rounded,
                                  size: 15.sp,
                                  color: selectedTab == 1
                                      ? const Color(0xFFF97316)
                                      : Colors.grey[600],
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  "Infos & Photo",
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.sp,
                                    color: selectedTab == 1
                                        ? const Color(0xFFF97316)
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          2: Container(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.picture_as_pdf_rounded,
                                  size: 15.sp,
                                  color: selectedTab == 2
                                      ? const Color(0xFFF97316)
                                      : Colors.grey[600],
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  "Aperçu PDF",
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.sp,
                                    color: selectedTab == 2
                                        ? const Color(0xFFF97316)
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        },
                        onValueChanged: (val) {
                          setModalState(() {
                            selectedTab = val ?? 0;
                          });
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Tab Content based on selectedTab
                  Expanded(
                    child: selectedTab == 0
                        ? _buildDiffTab(baseCv, currentAdaptedCv)
                        : selectedTab == 1
                        ? _buildInfoAndPhotoTab(currentAdaptedCv, (newCv) {
                            setModalState(() {
                              currentAdaptedCv = newCv;
                            });
                          })
                        : Column(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  clipBehavior: Clip.hardEdge,
                                  child: InteractiveViewer(
                                    panEnabled: true,
                                    minScale: 1.0,
                                    maxScale: 4.0,
                                    child: PdfPreview(
                                      key: ValueKey(
                                        '${currentAdaptedCv.templateId}_${currentAdaptedCv.primaryColor}_${currentAdaptedCv.secondaryColor}_${currentAdaptedCv.personalInfo.profileImageUrl}_${currentAdaptedCv.personalInfo.showAvatar}_${currentAdaptedCv.personalInfo.fullName}_${currentAdaptedCv.personalInfo.jobTitle}_${_getContactValue(currentAdaptedCv.personalInfo, 'location')}_${_getContactValue(currentAdaptedCv.personalInfo, 'email')}_${_getContactValue(currentAdaptedCv.personalInfo, 'phone')}',
                                      ),
                                      build: (format) =>
                                          CvPdfGenerator.generateCvPdf(
                                            currentAdaptedCv,
                                          ),
                                      canChangeOrientation: false,
                                      canChangePageFormat: false,
                                      useActions: false,
                                      allowPrinting: false,
                                      allowSharing: false,
                                      loadingWidget: const Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFFF97316),
                                        ),
                                      ),
                                      onError: (context, error) {
                                        return Center(
                                          child: Text(
                                            'Aperçu du CV indisponible',
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              color: const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 12.h),
                              // Template selector
                              _buildTemplateSelectorInsideSheet(
                                currentAdaptedCv,
                                (newCv) {
                                  setModalState(() {
                                    currentAdaptedCv = newCv;
                                  });
                                },
                              ),
                            ],
                          ),
                  ),
                  SizedBox(height: 16.h),

                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context); // Close review sheet
                            _runCvAdaptation(baseCv, job); // Regenerate!
                          },
                          icon: const Icon(
                            Icons.refresh,
                            color: Color(0xFFF97316),
                          ),
                          label: Text(
                            "Régénérer",
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFF97316),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFF97316)),
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        flex: 3,
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context); // Close review sheet
                            _applyWithAdaptedCv(baseCv, currentAdaptedCv, job);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF97316),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Text(
                            "Postuler avec ce CV",
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Annuler",
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDiffTab(CvModel baseCv, CvModel adaptedCv) {
    final diffWidgets = <Widget>[];

    // Profile Title
    if (baseCv.personalInfo.jobTitle != adaptedCv.personalInfo.jobTitle) {
      diffWidgets.add(
        _buildDiffItem(
          icon: Icons.work_outline,
          title: "Titre du Profil",
          original: baseCv.personalInfo.jobTitle,
          adapted: adaptedCv.personalInfo.jobTitle,
        ),
      );
    }

    // Accroche
    if (baseCv.personalInfo.summary != adaptedCv.personalInfo.summary) {
      diffWidgets.add(
        _buildDiffItem(
          icon: Icons.description_outlined,
          title: "Accroche / Résumé",
          original: baseCv.personalInfo.summary,
          adapted: adaptedCv.personalInfo.summary,
        ),
      );
    }

    // Compétences
    if (baseCv.skills != adaptedCv.skills) {
      diffWidgets.add(
        _buildDiffItem(
          icon: Icons.star_border_rounded,
          title: "Compétences clés",
          original: baseCv.skills,
          adapted: adaptedCv.skills,
        ),
      );
    }

    // Expériences professionnelles (comparaison simplifiée)
    if (baseCv.experiences.length == adaptedCv.experiences.length) {
      for (int i = 0; i < baseCv.experiences.length; i++) {
        final orig = baseCv.experiences[i];
        final adapt = adaptedCv.experiences[i];
        if (orig.description != adapt.description) {
          diffWidgets.add(
            _buildDiffItem(
              icon: Icons.business_center_outlined,
              title: "Expérience : ${orig.jobTitle} chez ${orig.company}",
              original: orig.description,
              adapted: adapt.description,
            ),
          );
        }
      }
    }

    // Projets (comparaison simplifiée)
    if (baseCv.projects.length == adaptedCv.projects.length) {
      for (int i = 0; i < baseCv.projects.length; i++) {
        final orig = baseCv.projects[i];
        final adapt = adaptedCv.projects[i];
        if (orig.description != adapt.description) {
          diffWidgets.add(
            _buildDiffItem(
              icon: Icons.folder_open_outlined,
              title: "Projet : ${orig.name}",
              original: orig.description,
              adapted: adapt.description,
            ),
          );
        }
      }
    }

    if (diffWidgets.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 48.sp,
              ),
              SizedBox(height: 12.h),
              Text(
                "Votre CV est déjà parfaitement ciblé pour cette offre !",
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14.sp,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: diffWidgets.length,
      separatorBuilder: (context, index) => SizedBox(height: 16.h),
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) => diffWidgets[index],
    );
  }

  Widget _buildDiffItem({
    required IconData icon,
    required String title,
    required String original,
    required String adapted,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header of the card
          Padding(
            padding: EdgeInsets.all(16.r),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFFF97316),
                    size: 18.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E3A8A),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (original.trim().isNotEmpty) ...[
                  Text(
                    "VERSION INITIALE",
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500],
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      original,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],

                Row(
                  children: [
                    Text(
                      "OPTIMISÉ PAR L'IA",
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF97316),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(100.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: const Color(0xFFF97316),
                            size: 10.sp,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            "Recommandé",
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 9.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFF97316),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5), // Light emerald/green
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    adapted,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13.sp,
                      color: const Color(0xFF065F46), // Deep emerald
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateSelectorInsideSheet(
    CvModel cv,
    Function(CvModel) onCvUpdated,
  ) {
    final templates = CvPdfGenerator.availableTemplates;

    // Parse the primary theme color of the CV
    Color primaryThemeColor;
    try {
      primaryThemeColor = Color(
        int.parse(cv.primaryColor.replaceFirst('#', '0xff')),
      );
    } catch (_) {
      primaryThemeColor = const Color(0xFFF97316); // Default orange
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
          child: Text(
            "Choisir un modèle de CV :",
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E3A8A),
            ),
          ),
        ),
        SizedBox(
          height: 60.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              final isSelected = cv.templateId == template.id;

              return GestureDetector(
                onTap: () {
                  onCvUpdated(cv.copyWith(templateId: template.id));
                },
                child: Container(
                  width: 100.w,
                  margin: EdgeInsets.only(right: 8.w, top: 4.h, bottom: 4.h),
                  padding: EdgeInsets.all(6.r),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryThemeColor.withOpacity(0.05)
                        : Colors.white,
                    border: Border.all(
                      color: isSelected ? primaryThemeColor : Colors.grey[300]!,
                      width: isSelected ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.insert_drive_file_outlined,
                        color: isSelected
                            ? primaryThemeColor
                            : Colors.grey[500],
                        size: 18.sp,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        template.name,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 10.sp,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? primaryThemeColor
                              : Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoAndPhotoTab(
    CvModel currentCv,
    Function(CvModel) onCvUpdated,
  ) {
    final info = currentCv.personalInfo;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Photo de profil & Avatar (Compacte & Utile)
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30.r,
                      backgroundColor: const Color(0xFFF1F5F9),
                      backgroundImage:
                          (info.profileImageUrl != null &&
                              info.profileImageUrl!.isNotEmpty)
                          ? NetworkImage(info.profileImageUrl!)
                          : null,
                      child:
                          (info.profileImageUrl == null ||
                              info.profileImageUrl!.isEmpty)
                          ? Icon(
                              Icons.person_rounded,
                              size: 32.r,
                              color: const Color(0xFF94A3B8),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: () =>
                            _pickAndUploadPhotoForCv(currentCv, onCvUpdated),
                        child: Container(
                          padding: EdgeInsets.all(5.r),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF97316),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 12.r,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Photo de profil du CV",
                        style: TextStyle(
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        "Personnalisez votre photo sur le CV généré.",
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _pickAndUploadPhotoForCv(currentCv, onCvUpdated),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: const Color(0xFFF97316)),
                    ),
                    child: Text(
                      "Changer",
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF97316),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Switch(
                  value: info.showAvatar,
                  activeColor: const Color(0xFFF97316),
                  onChanged: (val) {
                    onCvUpdated(
                      currentCv.copyWith(
                        personalInfo: info.copyWith(showAvatar: val),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 14.h),

          // En-tête des 6 Sections du CV
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
            child: Row(
              children: [
                const Icon(
                  Icons.edit_document,
                  color: Color(0xFFF97316),
                  size: 20,
                ),
                SizedBox(width: 8.w),
                Text(
                  "Modifier les sections du CV",
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),

          // 1. Informations de base
          _buildCvSectionTile(
            icon: Icons.person_outline_rounded,
            title: "1. Informations de base",
            subtitle: info.fullName.isNotEmpty
                ? info.fullName
                : "Nom, contacts, résumé...",
            onTap: () {
              _openCvSectionEditor(
                context,
                "1. Informations de base",
                CvBasicInfoEditor(
                  initialData: info,
                  onSaved: (newInfo) {
                    onCvUpdated(currentCv.copyWith(personalInfo: newInfo));
                  },
                ),
              );
            },
            onAiPolish: () => _polishCvSectionWithAi(
              context,
              currentCv,
              'summary',
              onCvUpdated,
            ),
          ),

          // 2. Compétences professionnelles
          _buildCvSectionTile(
            icon: Icons.bolt_rounded,
            title: "2. Compétences professionnelles",
            subtitle: currentCv.skills.isNotEmpty
                ? "Compétences ajoutées"
                : "Langages, outils, frameworks...",
            onTap: () {
              _openCvSectionEditor(
                context,
                "2. Compétences professionnelles",
                CvSkillsEditor(
                  initialData: currentCv.skills,
                  candidateSummary: info.summary,
                  onSaved: (newSkills) {
                    onCvUpdated(currentCv.copyWith(skills: newSkills));
                  },
                ),
              );
            },
            onAiPolish: () => _polishCvSectionWithAi(
              context,
              currentCv,
              'skills',
              onCvUpdated,
            ),
          ),

          // 3. Expérience professionnelle
          _buildCvSectionTile(
            icon: Icons.work_outline_rounded,
            title: "3. Expérience professionnelle",
            subtitle:
                "${currentCv.experiences.length} expérience(s) ajoutée(s)",
            onTap: () {
              _openCvSectionEditor(
                context,
                "3. Expérience professionnelle",
                CvExperiencesEditor(
                  initialData: currentCv.experiences,
                  onSaved: (newExps) {
                    onCvUpdated(currentCv.copyWith(experiences: newExps));
                  },
                ),
              );
            },
            onAiPolish: () => _polishCvSectionWithAi(
              context,
              currentCv,
              'experiences',
              onCvUpdated,
            ),
          ),

          // 4. Formation et diplômes
          _buildCvSectionTile(
            icon: Icons.school_outlined,
            title: "4. Formation et diplômes",
            subtitle: "${currentCv.educations.length} formation(s) ajoutée(s)",
            onTap: () {
              _openCvSectionEditor(
                context,
                "4. Formation et diplômes",
                CvEducationEditor(
                  initialData: currentCv.educations,
                  onSaved: (newEdus) {
                    onCvUpdated(currentCv.copyWith(educations: newEdus));
                  },
                ),
              );
            },
            onAiPolish: () => _polishCvSectionWithAi(
              context,
              currentCv,
              'summary',
              onCvUpdated,
            ),
          ),

          // 5. Projets réalisés
          _buildCvSectionTile(
            icon: Icons.folder_open_outlined,
            title: "5. Projets réalisés",
            subtitle: "${currentCv.projects.length} projet(s) ajouté(s)",
            onTap: () {
              _openCvSectionEditor(
                context,
                "5. Projets réalisés",
                CvProjectsEditor(
                  initialData: currentCv.projects,
                  onSaved: (newProjects) {
                    onCvUpdated(currentCv.copyWith(projects: newProjects));
                  },
                ),
              );
            },
            onAiPolish: () => _polishCvSectionWithAi(
              context,
              currentCv,
              'summary',
              onCvUpdated,
            ),
          ),

          // 6. Activités et loisirs
          _buildCvSectionTile(
            icon: Icons.sports_soccer_outlined,
            title: "6. Activités et loisirs",
            subtitle: "${currentCv.activities.length} activité(s) ajoutée(s)",
            onTap: () {
              _openCvSectionEditor(
                context,
                "6. Activités et loisirs",
                CvActivitiesEditor(
                  initialData: currentCv.activities,
                  onSaved: (newActivities) {
                    onCvUpdated(currentCv.copyWith(activities: newActivities));
                  },
                ),
              );
            },
            onAiPolish: () => _polishCvSectionWithAi(
              context,
              currentCv,
              'summary',
              onCvUpdated,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCvSectionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required VoidCallback onAiPolish,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
        leading: Container(
          padding: EdgeInsets.all(10.r),
          decoration: BoxDecoration(
            color: const Color(0xFFF97316).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(icon, color: const Color(0xFFF97316), size: 22.r),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11.sp, color: const Color(0xFF64748B)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onAiPolish,
              borderRadius: BorderRadius.circular(16.r),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFFFFEDD5), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: const Color(0xFFEA580C),
                      size: 12.r,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      "Optimiser",
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFC2410C),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 4.w),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade400,
              size: 20.r,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  void _openCvSectionEditor(
    BuildContext context,
    String title,
    Widget editorWidget,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.fromLTRB(
          16.w,
          12.h,
          16.w,
          MediaQuery.of(context).viewInsets.bottom + 16.h,
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(100.r),
                ),
              ),
            ),
            SizedBox(height: 10.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 1),
            SizedBox(height: 10.h),
            Expanded(child: editorWidget),
          ],
        ),
      ),
    );
  }

  Future<void> _polishCvSectionWithAi(
    BuildContext context,
    CvModel currentCv,
    String sectionName,
    Function(CvModel) onCvUpdated,
  ) async {
    bool isCancelled = false;
    _showAiLoader(
      context,
      "Optimisation de la section par l'IA...",
      onCancel: () {
        isCancelled = true;
      },
    );

    try {
      final supabase = Supabase.instance.client;
      if (sectionName == 'summary' || sectionName == 'base') {
        final text = currentCv.personalInfo.summary.trim().isEmpty
            ? currentCv.personalInfo.jobTitle
            : currentCv.personalInfo.summary;

        final response = await supabase.functions
            .invoke(
              'cv-ai-assist',
              body: {
                'action': 'polish_text',
                'text': text,
                'systemContent':
                    'Tu es un expert RH. Reformule et polis l\'accroche professionnelle pour la rendre très captivante et humaine, à la 1ère personne du singulier. Retourne UNIQUEMENT le texte amélioré.',
              },
            )
            .timeout(const Duration(seconds: 25));

        if (isCancelled || !mounted) return;
        Navigator.pop(context); // Fermer uniquement le loader

        if (response.status == 200 && response.data?['polishedText'] != null) {
          final polished = response.data['polishedText'].toString().trim();
          onCvUpdated(
            currentCv.copyWith(
              personalInfo: currentCv.personalInfo.copyWith(summary: polished),
            ),
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Accroche optimisée avec succès ! ✨"),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else if (sectionName == 'skills') {
        final response = await supabase.functions
            .invoke(
              'cv-ai-assist',
              body: {
                'action': 'polish_text',
                'text': currentCv.skills,
                'systemContent':
                    'Tu es un expert RH. Organise et améliore cette liste de compétences en catégories claires et percutantes. Retourne UNIQUEMENT la liste formatée.',
              },
            )
            .timeout(const Duration(seconds: 25));

        if (isCancelled || !mounted) return;
        Navigator.pop(context); // Fermer uniquement le loader

        if (response.status == 200 && response.data?['polishedText'] != null) {
          final polished = response.data['polishedText'].toString().trim();
          onCvUpdated(currentCv.copyWith(skills: polished));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Compétences optimisées avec succès ! ✨"),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else if (sectionName == 'experiences') {
        if (currentCv.experiences.isEmpty) {
          if (!isCancelled && mounted) Navigator.pop(context);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Ajoutez d'abord une expérience pour l'optimiser.",
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        final exps = List<CvExperience>.from(currentCv.experiences);
        for (int i = 0; i < exps.length; i++) {
          if (isCancelled) break;
          if (exps[i].description.trim().isNotEmpty) {
            final resp = await supabase.functions
                .invoke(
                  'cv-ai-assist',
                  body: {
                    'action': 'polish_text',
                    'text': exps[i].description,
                    'systemContent':
                        'Tu es un expert RH. Améliore ces puces d\'expérience professionnelle pour faire ressortir l\'impact et les réalisations concrètes avec des verbes d\'action. Retourne UNIQUEMENT le texte amélioré.',
                  },
                )
                .timeout(const Duration(seconds: 25));

            if (resp.status == 200 && resp.data?['polishedText'] != null) {
              exps[i] = exps[i].copyWith(
                description: resp.data['polishedText'].toString().trim(),
              );
            }
          }
        }

        if (isCancelled || !mounted) return;
        Navigator.pop(context); // Fermer uniquement le loader
        onCvUpdated(currentCv.copyWith(experiences: exps));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Expériences professionnelles optimisées avec succès ! ✨",
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (!isCancelled && mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (!isCancelled && mounted) Navigator.pop(context);
      debugPrint('Error polishing section: $e');
    }
  }

  String _getContactValue(CvPersonalInfo info, String fieldId) {
    try {
      final field = info.contactFields.firstWhere(
        (c) => c.id == fieldId || c.iconName == fieldId,
      );
      return field.value;
    } catch (_) {
      return '';
    }
  }

  CvPersonalInfo _updateContactValue(
    CvPersonalInfo info,
    String fieldId,
    String iconName,
    String label,
    String newValue,
  ) {
    final existingFields = List<CvContactField>.from(info.contactFields);
    final index = existingFields.indexWhere(
      (c) => c.id == fieldId || c.iconName == fieldId,
    );

    if (index >= 0) {
      existingFields[index] = CvContactField(
        id: existingFields[index].id,
        iconName: existingFields[index].iconName,
        label: existingFields[index].label,
        value: newValue,
        isVisible: existingFields[index].isVisible,
      );
    } else {
      existingFields.add(
        CvContactField(
          id: fieldId,
          iconName: iconName,
          label: label,
          value: newValue,
          isVisible: true,
        ),
      );
    }

    return info.copyWith(contactFields: existingFields);
  }

  Future<void> _pickAndUploadPhotoForCv(
    CvModel currentCv,
    Function(CvModel) onCvUpdated,
  ) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      var extension = pickedFile.name.split('.').last.toLowerCase();
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      String contentType = 'image/png';
      if (extension == 'jpg' || extension == 'jpeg') {
        contentType = 'image/jpeg';
      } else if (extension == 'webp') {
        contentType = 'image/webp';
      } else {
        contentType = 'image/png';
        extension = 'png';
      }

      final fileName =
          '${userId}_avatar_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final filePath = 'avatars/$fileName';

      await Supabase.instance.client.storage
          .from('cv_files')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      final publicUrl = Supabase.instance.client.storage
          .from('cv_files')
          .getPublicUrl(filePath);

      final updatedCv = currentCv.copyWith(
        personalInfo: currentCv.personalInfo.copyWith(
          profileImageUrl: publicUrl,
          showAvatar: true,
        ),
      );

      onCvUpdated(updatedCv);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Photo de profil mise à jour avec succès !"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error uploading avatar photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de l'envoi de la photo : $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _applyWithAdaptedCv(
    CvModel baseCv,
    CvModel adaptedCv,
    Map<String, dynamic> job,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: Color(0xFFF97316)),
            SizedBox(width: 16),
            Expanded(
              child: Text("Génération et enregistrement du nouveau CV..."),
            ),
          ],
        ),
      ),
    );

    try {
      final jobTitle = job['job_title'] ?? '';
      final cvToSave = adaptedCv.copyWith(
        id: null,
        title: "${baseCv.displayTitle} - Adapté pour $jobTitle",
      );

      final savedCv = await CvStorageService.saveCv(
        cvToSave,
        bypassQuota: true,
      );
      final pdfBytes = await CvPdfGenerator.generateCvPdf(savedCv);

      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception("Utilisateur non connecté");

      final fileName = '${user.id}_cv_${savedCv.id}.pdf';
      final filePath = 'cvs/$fileName';

      await _supabase.storage
          .from('cv_files')
          .uploadBinary(
            filePath,
            pdfBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final String publicUrl = _supabase.storage
          .from('cv_files')
          .getPublicUrl(filePath);

      if (mounted) {
        setState(() {
          job['adapted_cv_url'] = publicUrl;
        });

        Navigator.pop(context); // Close loading dialog

        // Swipe right programmatically
        _controller.swipe(CardSwiperDirection.right);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'CV adapté enregistré et postulation envoyée pour $jobTitle !',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Erreur lors de l'enregistrement ou de la postulation : $e",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Affiche un loader IA animé premium avec un design élégant
  void _showAiLoader(
    BuildContext ctx,
    String message, {
    VoidCallback? onCancel,
  }) {
    showDialog(
      context: ctx,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) =>
          _AiLoaderDialog(message: message, onCancel: onCancel),
    );
  }
}

/// Widget de loader IA animé avec pulsation et gradient
class _AiLoaderDialog extends StatefulWidget {
  final String message;
  final VoidCallback? onCancel;
  const _AiLoaderDialog({required this.message, this.onCancel});

  @override
  State<_AiLoaderDialog> createState() => _AiLoaderDialogState();
}

class _AiLoaderDialogState extends State<_AiLoaderDialog>
    with TickerProviderStateMixin {
  late AnimationController _scanController;
  late AnimationController _pulseController;
  late Animation<double> _scanAnimation;
  late Animation<double> _pulseAnimation;

  final List<String> _steps = [
    "Analyse de l'offre d'emploi...",
    "Optimisation du titre et de l'accroche...",
    "Adaptation des compétences clés...",
    "Personnalisation des expériences...",
    "Finalisation de votre CV ciblé...",
  ];
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();

    // Scan line animation (up and down)
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );

    // Subtle background pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _cycleSteps();
  }

  void _cycleSteps() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _currentStep = (_currentStep + 1) % _steps.length;
        });
        _cycleSteps();
      }
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 40.w),
        padding: EdgeInsets.symmetric(vertical: 36.h, horizontal: 24.w),
        decoration: BoxDecoration(
          // Dark premium gradient matching the project's Orange/Green branding
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A), // Deep Slate
              Color(0xFF042F1A), // Deep Forest Green
            ],
          ),
          borderRadius: BorderRadius.circular(28.r),
          border: Border.all(
            color: const Color(0xFF10B981).withOpacity(0.3), // Emerald Green
            width: 1.5.w,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF10B981,
              ).withOpacity(0.2), // Soft Green Glow
              blurRadius: 40,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // CV Scanner Animation
            Stack(
              alignment: Alignment.center,
              children: [
                // Pulse background glow (Green)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 130.w,
                      height: 130.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF10B981,
                            ).withOpacity(0.12 * _pulseAnimation.value),
                            blurRadius: 35,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Stylized CV document container (White/Slate)
                Container(
                  width: 72.w,
                  height: 96.h,
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  child: Stack(
                    children: [
                      // Fake lines representing CV layout
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header line (avatar circle + name line)
                          Row(
                            children: [
                              Container(
                                width: 14.w,
                                height: 14.w,
                                decoration: const BoxDecoration(
                                  color: Colors.white30,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Container(
                                width: 28.w,
                                height: 5.h,
                                decoration: BoxDecoration(
                                  color: Colors.white30,
                                  borderRadius: BorderRadius.circular(2.r),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 14.h),
                          // Content lines (White/Grey)
                          Container(
                            width: 46.w,
                            height: 4.h,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Container(
                            width: 38.w,
                            height: 4.h,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Container(
                            width: 42.w,
                            height: 4.h,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Container(
                            width: 22.w,
                            height: 4.h,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                          ),
                        ],
                      ),

                      // Animated scanning laser line (Orange)
                      AnimatedBuilder(
                        animation: _scanAnimation,
                        builder: (context, child) {
                          return Positioned(
                            top: _scanAnimation.value * 68.h,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 3.h,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF97316), // Orange
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFF97316,
                                    ).withOpacity(0.8),
                                    blurRadius: 8,
                                    spreadRadius: 1.5,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Tiny sparkles overlay representing AI (Green)
                Positioned(
                  top: 8.h,
                  right: 8.w,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Color(0xFF10B981), // Emerald Green
                          size: 20,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 28.h),

            // Title
            Text(
              "Intelligence Artificielle",
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 8.h),

            // Animated step text
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _steps[_currentStep],
                key: ValueKey(_currentStep),
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13.sp,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 28.h),

            // Premium progress indicator (Green)
            SizedBox(
              width: 180.w,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100.r),
                child: LinearProgressIndicator(
                  minHeight: 4.h,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF10B981),
                  ), // Emerald Green
                ),
              ),
            ),
            SizedBox(height: 12.h),

            Text(
              "Veuillez patienter...",
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11.sp,
                color: Colors.white38,
              ),
            ),
            SizedBox(height: 20.h),

            // Bouton d'annulation (Annuler)
            OutlinedButton.icon(
              onPressed: () {
                widget.onCancel?.call();
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: Colors.white.withOpacity(0.25),
                  width: 1,
                ),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              icon: Icon(
                Icons.close_rounded,
                size: 16.r,
                color: Colors.white70,
              ),
              label: Text(
                "Annuler",
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
