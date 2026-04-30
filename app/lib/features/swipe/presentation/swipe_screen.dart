import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:djossimatch/features/swipe/presentation/djossi_swipe_card.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:djossimatch/core/cache/local_cache.dart';
import 'package:djossimatch/core/services/match_notifier.dart';
import 'package:djossimatch/core/services/profile_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:djossimatch/core/utils/tag_normalizer.dart';

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key});

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

  // Nouveaux états pour le Premium
  int _swipeCount = 0;
  bool _isPremium = false;
  String? _cvUrl;
  String? _fullName;
  String? _sexe;
  bool _hasUnreadNotifications = false;

  // File d'attente pour les envois d'email (éviter le rate-limiting)
  final List<Map<String, dynamic>> _emailQueue = [];
  bool _isProcessingQueue = false;

  StreamSubscription<List<Map<String, dynamic>>>? _profileSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtime();
    _listenToProfileChanges();
    _checkUnreadNotifications();
  }

  Future<void> _checkUnreadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastViewed = prefs.getString('last_notifications_view') ?? DateTime(2000).toIso8601String();
      
      final response = await _supabase
          .from('notifications')
          .select('created_at')
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
        debugPrint('*** [NOTIFIER] Changement de profil détecté via ProfileNotifier ! Rechargement... ***');
        // Vider le cache de matching
        _matchScoreCache.clear();
        setState(() {
          _isLoading = true;
          _jobs = [];
          _swiperKey++; // Force la reconstruction du CardSwiper
        });
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _controller.dispose();
    super.dispose();
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
              _cvUrl = data.first['cv_url'];
              _fullName = data.first['full_name'];
              _sexe = data.first['sexe'];
            });

            // Si les secteurs ont changé → recharger complètement les offres
            if (skillsChanged) {
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
              });
              // 4. Recharger les offres avec les nouveaux secteurs
              _loadData();
            }
          }
        });
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

  Future<void> _loadData() async {
    // 0a. Charger les skills du cache SEULEMENT si pas déjà définis (par le realtime)
    if (_userSkills.isEmpty) {
      try {
        final cachedSkills = await LocalCache.load(LocalCache.skillsKey);
        if (cachedSkills != null && cachedSkills is List) {
          _userSkills = List<String>.from(cachedSkills);
        }
      } catch (e) {
        debugPrint('Erreur lecture cache skills: $e');
      }
    }

    // 0b. Charger le cache jobs immédiatement pour un affichage instantané (même hors ligne)
    try {
      final cachedJobs = await LocalCache.load(LocalCache.jobsKey);
      if (cachedJobs != null && cachedJobs is List && mounted) {
        var cachedList = List<Map<String, dynamic>>.from(cachedJobs);
        // Re-trier et filtrer le cache avec l'algorithme de matching actuel
        if (_sectorSkills.isNotEmpty) {
          // Filtrer les jobs non pertinents du cache aussi
          cachedList = cachedList.where((job) {
            return _calculateMatchScore(job) > 0;
          }).toList();
          cachedList.sort((a, b) {
            final scoreA = _calculateMatchScore(a);
            final scoreB = _calculateMatchScore(b);
            return scoreB.compareTo(scoreA);
          });
        }
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

      // 1. Récupérer les infos du profil (is_premium et skills)
      final profileResponse = await _supabase
          .from('profiles')
          .select('skills, is_premium, full_name, cv_url, sexe')
          .eq('id', userId)
          .maybeSingle();

      if (profileResponse != null) {
        final isPremium = profileResponse['is_premium'] ?? false;
        final premiumUntilRaw = profileResponse['premium_until'];
        if (isPremium && premiumUntilRaw != null) {
          final premiumUntil = DateTime.parse(premiumUntilRaw);
          _isPremium = premiumUntil.isAfter(DateTime.now());
        } else {
          _isPremium = isPremium;
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

      // 2. Récupérer les IDs des jobs déjà swipés (GAUCHE ou DROITE)
      final swipedResponse = await _supabase
          .from('swipes_log')
          .select('job_id')
          .eq('user_id', userId);

      final swipedJobIds = (swipedResponse as List)
          .where((s) => s['job_id'] != null)
          .map((s) => s['job_id'].toString())
          .toSet();

      // 2.5 Compter swipes du jour (GAUCHE + DROITE) pour la limite
      final today = DateTime.now().toIso8601String().substring(0, 10);
      try {
        final countResp = await _supabase
            .from('swipes_log')
            .select('id')
            .eq('user_id', userId)
            .gte('created_at', '${today}T00:00:00Z');

        _swipeCount = countResp != null ? (countResp as List).length : 0;
      } catch (e) {
        debugPrint('Erreur lors du comptage des swipes: $e');
        _swipeCount = 0;
      }

      // 3. Récupérer toutes les offres non swipées
      final jobsResponse = await _supabase
          .from('jobs')
          .select()
          .order('created_at', ascending: false);

      final allJobs = List<Map<String, dynamic>>.from(
        jobsResponse,
      ).where((job) => !swipedJobIds.contains(job['id'].toString())).toList();

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

      // 5. Sauvegarder dans le cache pour la prochaine fois
      await LocalCache.save(LocalCache.jobsKey, allJobs);

      if (mounted) {
        setState(() {
          _jobs = allJobs;
          _isLoading = false;
          _swiperKey++; // Force la reconstruction complète du swiper avec les nouvelles données
        });

        // Afficher un petit message si aucune nouvelle offre n'a été trouvée
        if (allJobs.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Scan terminé : aucune nouvelle offre correspondante.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement réseau: $e');
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



  bool _isGenericTag(String tag) {
    return TagNormalizer.isGeneric(tag);
  }

  /// Retourne les skills de l'utilisateur en filtrant les tags génériques
  List<String> get _sectorSkills {
    return _userSkills.where((s) => !_isGenericTag(s)).toList();
  }

  List<String> _getExpandedKeywords(String userSkill) {
    return TagNormalizer.getExpandedKeywords(userSkill).toList();
  }

  int _calculateMatchScore(Map<String, dynamic> job) {
    if (_userSkills.isEmpty) return 50;

    double totalScore = 0;
    int matchesCount = 0;

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
      
      bool matchedThisSkill = false;

      // 1. MATCH DIRECT PAR TAG (POIDS TRÈS FORT)
      for (final jobTag in allJobTags) {
        if (TagNormalizer.normalizeKey(jobTag) == TagNormalizer.normalizeKey(skillLower)) {
          currentSkillScore += isContractTag ? 400 : 300;
          matchedThisSkill = true;
          break;
        }
        // Match partiel uniquement pour les mots suffisamment longs
        if (skillLower.length > 3 && (TagNormalizer.normalizeKey(jobTag).contains(TagNormalizer.normalizeKey(skillLower)) || TagNormalizer.normalizeKey(skillLower).contains(TagNormalizer.normalizeKey(jobTag)))) {
          currentSkillScore += 150;
          matchedThisSkill = true;
          break;
        }
      }

      // 2. MATCH PAR SPÉCIALITÉ (POIDS FORT)
      if (!matchedThisSkill && jobSpecialty.isNotEmpty) {
        if (TagNormalizer.normalizeKey(jobSpecialty) == TagNormalizer.normalizeKey(skillLower)) {
          currentSkillScore += 150;
          matchedThisSkill = true;
        } else if (skillLower.length > 3 && (TagNormalizer.normalizeKey(jobSpecialty).contains(TagNormalizer.normalizeKey(skillLower)) ||
            TagNormalizer.normalizeKey(skillLower).contains(TagNormalizer.normalizeKey(jobSpecialty)))) {
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
      }
    }

    // FILTRAGE STRICT : Si l'utilisateur a des critères mais qu'aucun ne matche ce job
    if (matchesCount == 0 && _userSkills.isNotEmpty) {
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
    return const {'cdd', 'cdi', 'stage', 'freelance', 'intérim', 'alternance'}
        .contains(TagNormalizer.normalizeKey(tag));
  }

  /// Vérifie si un texte contient un mot ou pattern, avec gestion des frontières de mots
  /// pour les mots courts afin d'éviter les faux positifs (ex: 'it' dans 'cuisine').
  bool _matchWord(String text, String word) {
    final textLower = text.toLowerCase();
    final wordLower = TagNormalizer.normalizeKey(word);

    if (wordLower.isEmpty) return false;

    if (wordLower.length <= 3) {
      // Pour les mots courts (it, rh, cdd, btp), on exige des frontières de mots via Regex
      // \b assure que le mot est entouré d'espaces, ponctuation ou début/fin de ligne.
      final escaped = RegExp.escape(wordLower);
      return RegExp('\\b$escaped\\b', caseSensitive: false).hasMatch(textLower);
    }

    // Pour les mots longs, on accepte le contains standard pour plus de souplesse
    return textLower.contains(wordLower);
  }

  bool _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) {
    // BLOCAGE PHYSIQUE STRICT : Si pas premium et limite de 10 atteinte
    // On bloque TOUT mouvement (Gauche ou Droite)
    if (!_isPremium && _swipeCount >= 10) {
      _showPremiumLimitDialog();
      return false; // Bloque physiquement la carte
    }

    if (direction == CardSwiperDirection.right) {
      // Bloquer le Swipe Droite si l'utilisateur n'a pas mis de CV
      if (_cvUrl == null || _cvUrl!.isEmpty) {
        _showMissingCvDialog();
        return false; // Renvoie la carte au centre
      }

      _handleSwipe(previousIndex, 'right');
    } else if (direction == CardSwiperDirection.left) {
      _handleSwipe(previousIndex, 'left');
    }
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

      // 2. Traitement spécifique si c'est un swipe DROITE (postulation)
      if (direction == 'right') {
        debugPrint('*** [DIAGNOSTIC] DÉBUT SWIPE DROITE DÉTECTÉ ***');

        // Enregistrer la postulation (fire-and-forget)
        unawaited(
          _supabase
              .from('applications')
              .insert({
                'user_id': userId,
                'job_id': job['id'],
                'status': 'pending',
              })
              .then((_) {
                // Signaler à l'écran des matches de s'actualiser
                MatchNotifier.notifyNewMatch();
              })
              .catchError((e) {
                debugPrint('Erreur application insert: $e');
                return null;
              }),
        );

        debugPrint('*** [DIAGNOSTIC] URL CV: $_cvUrl ***');

        final whatsapp = job['whatsapp_number'];
        final email = job['contact_email'];
        final appLink =
            job['application_link'] ??
            (job['raw_data'] != null
                ? job['raw_data']['application_link']
                : null);

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
      }
    } catch (e) {
      debugPrint('Erreur lors du swipe: $e');
      if (e.toString().contains('Daily free swipe limit')) {
        _controller.undo(); // Ramène la carte à l'écran
        setState(
          () => _swipeCount = 10,
        ); // Resynchronise le compteur local de force
        if (mounted) _showPremiumLimitDialog();
      }
    }
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
            'cvUrl': _cvUrl,
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
            const Text('Fonction Premium'),
          ],
        ),
        content: Text(
          'La fonctionnalité "$feature" est réservée aux membres Premium.\n\nPassez au forfait illimité pour en profiter !',
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
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/premium').then((_) {
                if (mounted) {
                  setState(() => _isLoading = true);
                  _loadData();
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
            const Text('Limite atteinte !'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vous avez utilisé vos 10 swipes gratuits pour aujourd\'hui.',
            ),
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
            const Text(
              'Ou passez au illimité maintenant pour ne rater aucun Djorssi !',
              style: TextStyle(fontWeight: FontWeight.bold),
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
            onPressed: () {
              Navigator.pop(context);
              context.push('/premium').then((_) {
                if (mounted) {
                  setState(() => _isLoading = true);
                  _loadData();
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

      if (digits.length <= 10 && digits.length >= 8) {
        numbers.add(digits);
      } else if (digits.length > 10) {
        // Numéros collés — découper en blocs de 10 chiffres (format CI)
        String remaining = digits;

        if (remaining.startsWith('225') && remaining.length > 13) {
          while (remaining.isNotEmpty) {
            if (remaining.startsWith('225') && remaining.length >= 13) {
              numbers.add(remaining.substring(0, 13));
              remaining = remaining.substring(13);
            } else if (remaining.length >= 10) {
              numbers.add(remaining.substring(0, 10));
              remaining = remaining.substring(10);
            } else if (remaining.length >= 8) {
              numbers.add(remaining);
              remaining = '';
            } else {
              remaining = '';
            }
          }
        } else {
          while (remaining.isNotEmpty) {
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

              final userId = _supabase.auth.currentUser?.id;
              if (userId != null) {
                _supabase
                    .from('applications')
                    .update({'status': 'action_taken'})
                    .eq('user_id', userId)
                    .eq('job_id', jobId)
                    .catchError((_) => null);
              }

              String interestText = (_sexe == 'Femme')
                  ? 'intéressée'
                  : 'intéressé';
              String companyText =
                  (companyName.isNotEmpty &&
                      companyName.toLowerCase() != 'inconnu')
                  ? companyName
                  : 'votre structure ou votre entreprise';
              String textMessage =
                  "Bonjour, je suis $interestText par le poste de $jobTitle au sein de $companyText vu sur Djorssi-Match. Veuillez trouver mon CV ci-joint.";

              final message = Uri.encodeComponent(textMessage);
              final whatsappAppUrl = Uri.parse(
                "whatsapp://send?phone=$finalPhone&text=$message",
              );
              final webUrl = Uri.parse(
                "https://wa.me/$finalPhone?text=$message",
              );

              try {
                bool launched = await launchUrl(
                  whatsappAppUrl,
                  mode: LaunchMode.externalApplication,
                );
                if (!launched) {
                  launched = await launchUrl(
                    webUrl,
                    mode: LaunchMode.externalApplication,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Impossible d'ouvrir WhatsApp"),
                    ),
                  );
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

              final userId = _supabase.auth.currentUser?.id;
              if (userId != null) {
                _supabase
                    .from('applications')
                    .update({'status': 'action_taken'})
                    .eq('user_id', userId)
                    .eq('job_id', jobId)
                    .catchError((_) => null);
              }

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
                  await prefs.setString('last_notifications_view', DateTime.now().toIso8601String());
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
          await _loadData();
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
                                      numberOfCardsDisplayed: _jobs.isEmpty 
                                          ? 1 
                                          : (_jobs.length >= 3 ? 3 : _jobs.length),
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
                                                  deadline: job['deadline'],
                                                  applicationLink:
                                                      job['application_link'] ??
                                                      (job['raw_data'] != null
                                                          ? job['raw_data']['application_link']
                                                          : null),
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
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 16.h),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _isLoading = true);
                    _loadData();
                  },
                  icon: const Icon(Icons.refresh, size: 20),
                  label: Text(
                    'Lancer un nouveau scan',
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
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
    if (!_isPremium) {
      _showPremiumFeatureDialog('Retour en arrière');
      return;
    }

    // Dans CardSwiper, l'undo ramène la carte précédente
    _controller.undo();

    setState(() {
      if (_swipeCount > 0) _swipeCount--;
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

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(Icons.close_rounded, Colors.red, () {
          if (!_isPremium && _swipeCount >= 10) {
            _showPremiumLimitDialog();
            return;
          }
          _controller.swipe(CardSwiperDirection.left);
        }),
        _buildActionButton(
          Icons.replay_rounded,
          _isPremium ? const Color(0xFFF59E0B) : Colors.grey,
          _handleUndo,
          isMini: true,
          locked: false, // Cadenas retiré à la demande de l'utilisateur
        ),
        _buildActionButton(Icons.favorite_rounded, Colors.green, () {
          if (!_isPremium && _swipeCount >= 10) {
            _showPremiumLimitDialog();
            return;
          }
          _controller.swipe(CardSwiperDirection.right);
        }),
      ],
    );
  }

  Widget _buildActionButton(
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    bool isMini = false,
    bool locked = false,
  }) {
    final size = isMini ? 55.r : 70.r;
    final iconSize = isMini ? 24.r : 32.r;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                spreadRadius: 2.r,
                blurRadius: 10.r,
                offset: Offset(0, 4.h),
              ),
            ],
            border: _isPremium && !isMini && color == Colors.green
                ? Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.5),
                    width: 2,
                  )
                : null,
          ),
          child: IconButton(
            icon: Icon(icon, color: color, size: iconSize),
            onPressed: onPressed,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
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
            child: Text('Plus tard', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openStoreForRating();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: const Text('Noter maintenant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _openStoreForRating() async {
    final InAppReview inAppReview = InAppReview.instance;
    try {
      await inAppReview.openStoreListing(
        appStoreId: '6740356525',
      );
    } catch (e) {
      debugPrint('Erreur ouverture store: $e');
    }
  }
}
