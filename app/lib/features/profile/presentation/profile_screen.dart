import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/version_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:in_app_review/in_app_review.dart';
import '../../../core/services/profile_notifier.dart';
import '../../../core/cache/local_cache.dart';
import '../../cv_generator/models/cv_model.dart';
import '../../cv_generator/services/cv_ai_import_service.dart';
import '../../recruiter/presentation/widgets/candidate_cv_swipe_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  List<String> _skills = [];
  String? _fullName;
  int _unreadSupportReplies = 0;

  StreamSubscription<List<Map<String, dynamic>>>? _profileSubscription;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isHighlightingVisibility = false;
  Timer? _highlightTimer;

  /// Getter centralisé : vérifie `is_premium` ET `premium_until` pour
  /// déterminer si l'utilisateur est réellement premium actif.
  bool get _isActivePremium {
    if (!VersionService.showPremium) return false; // Premium masqué globalement
    final isPremium = _profileData?['is_premium'] ?? false;
    if (!isPremium) return false;
    final premiumUntilRaw = _profileData?['premium_until'];
    if (premiumUntilRaw != null) {
      try {
        final premiumUntil = DateTime.parse(premiumUntilRaw.toString());
        return premiumUntil.isAfter(DateTime.now());
      } catch (e) {
        debugPrint('ProfileScreen: Erreur parsing premium_until: $e');
        return false;
      }
    }
    return true; // is_premium=true sans date d'expiration → premium indéfini
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    ProfileNotifier.highlightVisibilityNotifier.addListener(_checkHighlightVisibility);

    _loadProfile();
    _setupRealtime();

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkHighlightVisibility());
  }

  void _checkHighlightVisibility() {
    if (ProfileNotifier.highlightVisibilityNotifier.value) {
      if (mounted) {
        setState(() => _isHighlightingVisibility = true);
        _pulseController.repeat(reverse: true);
        _highlightTimer?.cancel();
        _highlightTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            _pulseController.stop();
            setState(() => _isHighlightingVisibility = false);
            ProfileNotifier.highlightVisibilityNotifier.value = false;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _highlightTimer?.cancel();
    ProfileNotifier.highlightVisibilityNotifier.removeListener(_checkHighlightVisibility);
    _profileSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Le Realtime gère déjà les mises à jour du profil.
    // Pas besoin de recharger ici (économie d'Egress).
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Le Realtime gère déjà les mises à jour du profil.
    // Pas besoin de recharger à chaque retour de navigation (économie d'Egress).
  }

  /// Abonnement realtime pour que le profil se mette à jour automatiquement
  void _setupRealtime() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _profileSubscription = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((data) {
          if (data.isNotEmpty && mounted) {
            // Sauvegarder dans le cache local
            LocalCache.save(LocalCache.profileKey, data.first);
            setState(() {
              _profileData = data.first;
              _skills = List<String>.from(data.first['skills'] ?? []);
              _fullName = data.first['full_name'];
            });
          }
        });
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    // 1. Lire le cache immédiatement pour l'affichage instantané
    try {
      final cachedProfile = await LocalCache.load(LocalCache.profileKey);
      if (cachedProfile != null && cachedProfile is Map<String, dynamic> && mounted) {
        setState(() {
          _profileData = cachedProfile;
          _skills = List<String>.from(cachedProfile['skills'] ?? []);
          _fullName = cachedProfile['full_name'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur lecture cache profil: $e');
    }

    // 2. Si le cache est frais et qu'on ne force pas, s'arrêter là (économie d'Egress)
    try {
      final isFresh = await LocalCache.isFresh(LocalCache.profileKey, LocalCache.profileTTL);
      if (isFresh && !forceRefresh) {
        debugPrint('*** [CACHE] Profil chargé depuis le cache frais (TTL) - Pas d\'appel réseau ***');
        return;
      }
    } catch (e) {
      debugPrint('Erreur vérification cache profil: $e');
    }

    // Sinon, charger depuis Supabase
    setState(() => _isLoading = _profileData == null);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await _supabase
          .from('profiles')
          .select('id, full_name, skills, cv_url, is_premium, premium_until, sexe, is_visible_to_recruiters, parsed_cv')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        final profileMap = Map<String, dynamic>.from(response);
        
        final parsedCvStr = (response['parsed_cv'] ?? '').toString();
        // Purge si le profil contient les anciennes données fictives de test
        if (parsedCvStr.contains('Djossi Tech') || parsedCvStr.contains('Silicon Abidjan')) {
          await _supabase.from('profiles').update({
            'parsed_cv': null,
          }).eq('id', user.id);

          profileMap['parsed_cv'] = null;
        }

        await LocalCache.save(LocalCache.profileKey, profileMap);
        
        if (mounted) {
          setState(() {
            _profileData = profileMap;
            _skills = List<String>.from(response['skills'] ?? []);
            _fullName = response['full_name'];
          });
        }
      }

      if (user != null) {
        final unreadRes = await _supabase
            .from('support_messages')
            .select('id')
            .eq('user_id', user.id)
            .eq('is_read', false);
        if (mounted) {
          setState(() {
            _unreadSupportReplies = (unreadRes as List).length;
          });
        }
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement du profil: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _navigateToEditProfile() async {
    final result = await context.push('/complete-profile');
    // Si le profil a été modifié, recharger les données
    if (result == true && mounted) {
      _loadProfile(forceRefresh: true);
    }
  }

  Future<void> _toggleRecruiterVisibility(bool value) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    if (!value) {
      // Désactivation directe
      await _updateVisibilityInSupabase(userId, false);
      return;
    }

    // 1. Vérifier si un CV existe
    final cvUrl = (_profileData?['cv_url'] as String?)?.trim();
    if (cvUrl == null || cvUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Veuillez d\'abord générer ou importer un CV dans l\'onglet "Mon CV".',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2. Modale moderne de confirmation (style BottomSheet bleu)
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 28.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Poignée supérieure (Drag Handle)
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 20.h),

              // Badge Icône Bleu Lumineux
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
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
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

              // Titre
              Text(
                'Visibilité Recruteur',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 12.h),

              // Description
              Text(
                'En activant cette option, votre profil et votre parcours professionnel seront rendus visibles auprès des chercheurs de têtes et recruteurs en quête de talents.\n\nVotre CV sera automatiquement synthétisé et préparé pour leur être présenté de manière claire et professionnelle.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5.sp,
                  color: const Color(0xFF475569),
                  height: 1.45,
                ),
              ),
              SizedBox(height: 24.h),

              // Bouton d'action principal (Bleu arrondi)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: Text(
                    'Accepter & Synthétiser',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.h),

              // Bouton d'annulation
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Annuler',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) {
      await _updateVisibilityInSupabase(userId, false);
      return;
    }

    // 3. Modale de chargement & Synthèse du CV en amont
    _showSynthesisLoadingDialog();

    try {
      CvModel? cvModel;
      final existingParsed = _profileData?['parsed_cv'];

      if (existingParsed != null && existingParsed is Map<String, dynamic> && existingParsed.isNotEmpty) {
        final parsedStr = existingParsed.toString();
        if (!parsedStr.contains('Djossi Tech') && !parsedStr.contains('Silicon Abidjan')) {
          try {
            final parsed = CvModel.fromJson(existingParsed);
            if (parsed.experiences.isNotEmpty || parsed.educations.isNotEmpty) {
              cvModel = parsed;
            }
          } catch (e) {
            debugPrint('Erreur lecture parsed_cv existant: $e');
          }
        }
      }

      if (cvModel == null) {
        final response = await http.get(Uri.parse(cvUrl)).timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) {
          throw Exception('Impossible de télécharger le CV (${response.statusCode})');
        }

        final bytes = response.bodyBytes;
        final rawText = CvAiImportService.extractTextFromPdf(bytes);
        cvModel = await CvAiImportService.analyzeWithMistral(rawText);
      }

      // Sauvegarde dans profiles (parsed_cv) et user_cvs
      await _supabase.from('profiles').update({
        'is_visible_to_recruiters': true,
        'parsed_cv': cvModel.toJson(),
      }).eq('id', userId);

      try {
        await _supabase.rpc('save_candidate_parsed_cv', params: {
          'p_candidate_id': userId,
          'p_cv_data': cvModel.toJson(),
          'p_title': cvModel.title.isNotEmpty ? cvModel.title : 'CV Importé',
        });
      } catch (e) {
        debugPrint('Erreur save_candidate_parsed_cv: $e');
      }

      // Mettre à jour le cache local
      if (_profileData != null) {
        final updatedData = Map<String, dynamic>.from(_profileData!);
        updatedData['is_visible_to_recruiters'] = true;
        updatedData['parsed_cv'] = cvModel.toJson();
        await LocalCache.save(LocalCache.profileKey, updatedData);
      }

      if (mounted) {
        setState(() {
          if (_profileData != null) {
            _profileData!['is_visible_to_recruiters'] = true;
            _profileData!['parsed_cv'] = cvModel!.toJson();
          }
        });

        Navigator.of(context).pop(); // Fermer le loader
        _showCandidateRecruiterPreview(cvUrl);
      }
    } catch (e) {
      debugPrint('Erreur synthèse en amont du CV: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Fermer le loader
        setState(() {
          if (_profileData != null) {
            _profileData!['is_visible_to_recruiters'] = false;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la préparation de votre profil : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSynthesisLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        content: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFFF97316), strokeWidth: 3),
              SizedBox(height: 20.h),
              Text(
                'Préparation & Synthèse de votre profil...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              SizedBox(height: 8.h),
              Text(
                'Votre CV est en cours de structuration pour être présenté aux recruteurs.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5.sp, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateVisibilityInSupabase(String userId, bool value) async {
    try {
      await _supabase
          .from('profiles')
          .update({'is_visible_to_recruiters': value})
          .eq('id', userId);

      if (_profileData != null) {
        final updatedData = Map<String, dynamic>.from(_profileData!);
        updatedData['is_visible_to_recruiters'] = value;
        await LocalCache.save(LocalCache.profileKey, updatedData);
      }

      if (mounted) {
        setState(() {
          if (_profileData != null) {
            _profileData!['is_visible_to_recruiters'] = value;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Votre CV est prêt et visible par les recruteurs !'
                  : 'Votre CV n\'est plus visible par les recruteurs.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur update visibilité: $e');
    }
  }

  void _showCandidateRecruiterPreview(String cvUrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                child: Row(
                  children: [
                    Icon(Icons.visibility_rounded, color: const Color(0xFFF97316), size: 22.r),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aperçu de votre profil recruteur',
                            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                          ),
                          Text(
                            'Voici exactement comment votre profil sera présenté aux recruteurs.',
                            style: TextStyle(fontSize: 12.sp, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(16.r),
                  child: CandidateCvSwipeCard(
                    candidateId: _supabase.auth.currentUser?.id,
                    fullName: _fullName ?? 'Mon Profil',
                    skills: _skills,
                    cvUrl: cvUrl,
                    sexe: _profileData?['sexe'],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.r),
                child: SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      final userId = _supabase.auth.currentUser?.id;
                      if (userId != null) {
                        await _updateVisibilityInSupabase(userId, true);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.white, size: 22.r),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: Text(
                                    'Fiche & Parcours enregistrée et visible par les recruteurs !',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5.sp),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                            margin: EdgeInsets.all(16.r),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                    ),
                    child: Text(
                      'Parfait, tout est bon !',
                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Se déconnecter',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await LocalCache.clearAll();
      unawaited(_supabase.auth.signOut());
      if (mounted) {
        context.go('/auth');
      }
    }
  }

  Future<void> _deleteAccount() async {
    final surveyResult = await _showDeleteSurveySheet(context);
    if (surveyResult == null) return;

    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      final accessToken = _supabase.auth.currentSession?.accessToken;
      if (userId == null || accessToken == null) {
        throw 'Utilisateur non identifié ou session expirée. Veuillez vous reconnecter.';
      }

      // 1. Appeler l'Edge Function pour supprimer le compte définitivement (Auth + Profil)
      await _supabase.functions.invoke(
        'delete-account',
        body: {
          'reason': surveyResult['reason'],
          'feedback': surveyResult['feedback'],
        },
      );

        // 2. Déconnexion locale pour forcer le nettoyage de la session et du cache
        await LocalCache.clearAll();
        await _supabase.auth.signOut();

        if (mounted) {
          // 3. Afficher un message de confirmation explicite
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Compte supprimé'),
              content: const Text(
                'Votre compte et toutes vos données ont été définitivement supprimés de nos serveurs.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/auth');
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        debugPrint('Erreur lors de la suppression du compte: $e');
        if (mounted) {
          String errorMessage = 'Une erreur technique est survenue.';
          if (e.toString().contains('Database error')) {
            errorMessage =
                'Erreur de base de données. Veuillez réessayer ou contacter le support.';
          } else if (e.toString().contains('500')) {
            errorMessage =
                'Le serveur a rencontré une erreur lors de la suppression (500).';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Échec de la suppression : $errorMessage'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    }

  Future<Map<String, String>?> _showDeleteSurveySheet(BuildContext context) async {
    String? selectedReason;
    final feedbackController = TextEditingController();
    bool confirmIrreversible = false;

    final reasons = [
      "J'ai trouvé un travail grâce à l'application 🎉",
      "J'ai trouvé un travail par un autre moyen",
      "Je ne trouve pas d'offres intéressantes",
      "L'application a trop de bugs",
      "C'est trop cher / limites trop contraignantes",
      "Autre raison",
    ];

    return await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28.r),
          topRight: Radius.circular(28.r),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isFormValid = selectedReason != null && confirmIrreversible;

            return Padding(
              padding: EdgeInsets.only(
                left: 24.w,
                right: 24.w,
                top: 24.h,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40.w,
                        height: 5.h,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      'Supprimer mon compte 😢',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'Nous sommes désolés de vous voir partir. Aidez-nous à nous améliorer en indiquant la raison de votre départ :',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: const Color(0xFF64748B),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20.h),
                    // Reasons list
                    ...reasons.map((reason) {
                      final isSelected = selectedReason == reason;
                      return GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            selectedReason = reason;
                          });
                        },
                        child: Container(
                          margin: EdgeInsets.only(bottom: 8.h),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 14.h,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFF97316).withOpacity(0.05)
                                : const Color(0xFFF8FAFC),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFF97316)
                                  : const Color(0xFFE2E8F0),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                color: isSelected
                                    ? const Color(0xFFF97316)
                                    : const Color(0xFF94A3B8),
                                size: 20.r,
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    SizedBox(height: 16.h),
                    // Optional feedback text field
                    Text(
                      'Un commentaire à ajouter ? (Optionnel)',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: feedbackController,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: 'Partagez vos suggestions ou remarques...',
                        hintStyle: TextStyle(
                          fontSize: 13.sp,
                          color: const Color(0xFF94A3B8),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: const BorderSide(color: Color(0xFFF97316)),
                        ),
                        contentPadding: EdgeInsets.all(16.r),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    // Irreversible warning toggle
                    GestureDetector(
                      onTap: () {
                        setSheetState(() {
                          confirmIrreversible = !confirmIrreversible;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: confirmIrreversible
                                ? Colors.red.shade400
                                : Colors.red.shade200,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: confirmIrreversible,
                              onChanged: (val) {
                                setSheetState(() {
                                  confirmIrreversible = val ?? false;
                                });
                              },
                              activeColor: Colors.red,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                "Je comprends que cette action est définitive et supprimera toutes mes données de manière irréversible.",
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.red.shade900,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              'Garder mon compte',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isFormValid
                                ? () {
                                    Navigator.pop(context, {
                                      'reason': selectedReason!,
                                      'feedback': feedbackController.text.trim(),
                                    });
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.red.shade200,
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Supprimer',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
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
      },
    );
  }

  Future<void> _shareApp() async {
    const String text = 'Découvrez Djorssi Match, l\'application qui révolutionne la recherche d\'emploi par le swipe ! 🚀\n\nAndroid: https://play.google.com/store/apps/details?id=com.djossimatch.djossimatch\niPhone: https://apps.apple.com/us/app/djorssi-match/id6767549287\nWeb: https://www.djorssi-match.com';
    await Share.share(text, subject: 'Trouve ton prochain job sur Djorssi Match !');
  }

  Future<void> _rateApp() async {
    final InAppReview inAppReview = InAppReview.instance;
    try {
      await inAppReview.openStoreListing(
        appStoreId: '6767549287',
      );
    } catch (e) {
      debugPrint('Erreur lors de l\'ouverture du store : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFF97316)),
      );
    }

    final user = _supabase.auth.currentUser;
    final profilePhone = _profileData?['phone_number']?.toString();
    final profileEmail = _profileData?['email']?.toString();
    final contactInfo = (profilePhone != null && profilePhone.isNotEmpty)
        ? profilePhone
        : (profileEmail != null && profileEmail.isNotEmpty)
            ? profileEmail
            : (user?.phone ?? user?.email ?? '');

    final sexe = _profileData?['sexe']?.toString();
    final IconData avatarIcon;
    final Color avatarBgColor;
    final Color avatarIconColor;

    if (sexe == 'Femme') {
      avatarIcon = Icons.face_3;
      avatarBgColor = const Color(0xFFFDF2F8); // pink-50
      avatarIconColor = const Color(0xFFEC4899); // pink-500
    } else if (sexe == 'Homme') {
      avatarIcon = Icons.face_6;
      avatarBgColor = const Color(0xFFEFF6FF); // blue-50
      avatarIconColor = const Color(0xFF3B82F6); // blue-500
    } else {
      avatarIcon = Icons.person;
      avatarBgColor = const Color(0xFFF1F5F9); // slate-100
      avatarIconColor = const Color(0xFF94A3B8); // slate-400
    }

    final isPremiumUser = _isActivePremium;
    final Color bgToUse = isPremiumUser ? const Color(0xFFFFFBEB) : avatarBgColor;
    final Color iconColorToUse = isPremiumUser ? const Color(0xFFF59E0B) : avatarIconColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Mon Profil',
          style: TextStyle(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 22.sp,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        color: const Color(0xFFF97316),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
          children: [
            // Section Avatar & Nom
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 120.r,
                        height: 120.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: _isActivePremium
                                ? const Color(0xFFF59E0B)
                                : Colors.white,
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Container(
                            color: bgToUse,
                            alignment: Alignment.center,
                            child: Icon(
                              avatarIcon,
                              size: 70.r,
                              color: iconColorToUse,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _navigateToEditProfile,
                          child: Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF97316),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 18.r,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Bienvenue, ${_fullName ?? 'Utilisateur Djorssi'}',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      if (_isActivePremium)
                        Padding(
                          padding: EdgeInsets.only(left: 8.w),
                          child: Icon(
                            Icons.verified,
                            color: const Color(0xFFF59E0B),
                            size: 24.r,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      gradient: _isActivePremium
                          ? const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                            )
                          : null,
                      color: _isActivePremium
                          ? null
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: _isActivePremium
                          ? [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isActivePremium)
                          Padding(
                            padding: EdgeInsets.only(right: 6.w),
                            child: Icon(
                              Icons.workspace_premium,
                              color: Colors.white,
                              size: 14.r,
                            ),
                          ),
                        Text(
                          VersionService.showPremium
                              ? (_isActivePremium
                                  ? 'MEMBRE VIP'
                                  : 'Utilisateur Freemium')
                              : 'Candidat',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing:
                                _isActivePremium ? 1 : 0,
                            color: _isActivePremium
                                ? Colors.white
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // Premium Banner
            if (VersionService.showPremium) ...[
              _buildPremiumBanner(),
              SizedBox(height: 16.h),
            ],

            // Section Secteurs d'intérêt (Skills)
            _buildCardSection(
              title: 'Mes Secteurs',
              onEdit: _navigateToEditProfile,
              child: InkWell(
                onTap: _navigateToEditProfile,
                child: _skills.isEmpty
                    ? Text(
                        'Aucun secteur sélectionné',
                        style: TextStyle(
                          color: const Color(0xFF94A3B8),
                          fontSize: 14.sp,
                        ),
                      )
                    : Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: _skills
                            .map(
                              (skill) => Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 6.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(100.r),
                                ),
                                child: Text(
                                  skill,
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ),

            SizedBox(height: 16.h),

            // Autres Options
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: Column(
                children: [
                  _buildOptionTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Alertes Emplois',
                    subtitle: 'Gérer mes notifications',
                    trailing: (VersionService.showPremium && !_isActivePremium)
                        ? Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF97316).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              'PREMIUM',
                              style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFF97316),
                              ),
                            ),
                          )
                        : null,
                    onTap: () {
                      if (!VersionService.featEmailAlerts) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Les alertes emplois par email sont actuellement désactivées.',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      context.push('/job-alerts');
                    },
                  ),
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isHighlightingVisibility ? _pulseAnimation.value : 1.0,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            color: _isHighlightingVisibility
                                ? const Color(0xFF3B82F6).withOpacity(0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: _isHighlightingVisibility
                                  ? const Color(0xFF3B82F6)
                                  : Colors.transparent,
                              width: _isHighlightingVisibility ? 2 : 0,
                            ),
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: _buildOptionTile(
                      icon: Icons.visibility,
                      title: 'Visible par les recruteurs',
                      subtitle: 'Permettre aux recruteurs de voir mon CV',
                      color: Colors.blue,
                      showArrow: false,
                      trailing: Switch(
                        value: _profileData?['is_visible_to_recruiters'] == true,
                        onChanged: _toggleRecruiterVisibility,
                        activeColor: const Color(0xFFF97316),
                      ),
                    ),
                  ),
                  _buildOptionTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Suggestions & Questions',
                    subtitle: 'Partager vos idées ou poser des questions',
                    color: Colors.teal,
                    trailing: _unreadSupportReplies > 0
                        ? Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Text(
                              '$_unreadSupportReplies',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : null,
                    onTap: () => context.push('/support').then((_) {
                      if (mounted) _loadProfile();
                    }),
                  ),
                  _buildOptionTile(
                    icon: Icons.info_outline_rounded,
                    title: 'À propos',
                    subtitle: 'Visiter notre site web',
                    color: Colors.blue,
                    onTap: () async {
                      final url = Uri.parse('https://www.djorssi-match.com/');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  _buildOptionTile(
                    icon: Icons.share_rounded,
                    title: 'Partager l\'application',
                    subtitle: 'Inviter des amis',
                    color: const Color(0xFFF97316),
                    onTap: _shareApp,
                  ),
                  _buildOptionTile(
                    icon: Icons.star_outline_rounded,
                    title: 'Noter l\'application',
                    subtitle: 'Donnez votre avis sur le store',
                    color: Colors.amber.shade700,
                    onTap: _rateApp,
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  _buildOptionTile(
                    icon: Icons.logout_rounded,
                    title: 'Se déconnecter',
                    color: Colors.red,
                    showArrow: false,
                    onTap: _signOut,
                  ),
                  _buildOptionTile(
                    icon: Icons.delete_forever_rounded,
                    title: 'Supprimer mon compte',
                    color: Colors.red.shade900,
                    showArrow: false,
                    onTap: _deleteAccount,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumBanner() {
    // Si le mode Premium est désactivé à distance (pour la validation Apple)
    // on cache systématiquement la bannière Premium.
    if (!VersionService.showPremium) {
      return const SizedBox.shrink();
    }

    final isPremium = _isActivePremium;
    final premiumUntilRaw = _profileData?['premium_until'];
    String subtitle = 'Boostez votre profil et matchez plus vite !';
    if (isPremium) {
      subtitle = 'Tous vos avantages sont activés ✓';
      if (premiumUntilRaw != null) {
        try {
          final date = DateTime.parse(premiumUntilRaw.toString()).toLocal();
          final day = date.day.toString().padLeft(2, '0');
          final month = date.month.toString().padLeft(2, '0');
          final year = date.year.toString();
          subtitle = 'Premium actif jusqu\'au $day/$month/$year ✓';
        } catch (e) {
          debugPrint('Error parsing premium_until: $e');
        }
      }
    }

    return Container(
      clipBehavior: Clip.antiAlias, // Pour que les cercles ne dépassent pas
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPremium
              ? [const Color(0xFF0F172A), const Color(0xFF334155)]
              : [
                  const Color(0xFFF97316),
                  const Color(0xFFEA580C),
                  const Color(0xFFC2410C),
                ],
        ),
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: [
          BoxShadow(
            color:
                (isPremium ? const Color(0xFF0F172A) : const Color(0xFFF97316))
                    .withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Éléments de décoration en arrière-plan
          Positioned(
            right: -20.r,
            top: -20.r,
            child: Container(
              width: 100.r,
              height: 100.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            left: -10.r,
            bottom: -30.r,
            child: Container(
              width: 80.r,
              height: 80.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),

          // Contenu principal
          Padding(
            padding: EdgeInsets.all(16.r),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    isPremium
                        ? Icons.workspace_premium_rounded
                        : Icons.workspace_premium_outlined,
                    color: isPremium ? const Color(0xFFF59E0B) : Colors.white,
                    size: 24.r,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isPremium ? 'MEMBRE PREMIUM' : 'PASSEZ AU PREMIUM',
                        style: TextStyle(
                          color: isPremium
                              ? const Color(0xFFF59E0B)
                              : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.sp,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 11.sp,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (!isPremium) SizedBox(width: 8.w),
                if (!isPremium)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.push('/premium').then((_) {
                        if (mounted) _loadProfile();
                      }),
                      borderRadius: BorderRadius.circular(12.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          'VOIR',
                          style: TextStyle(
                            color: const Color(0xFFF97316),
                            fontWeight: FontWeight.w900,
                            fontSize: 11.sp,
                          ),
                        ),
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

  Widget _buildCardSection({
    required String title,
    VoidCallback? onEdit,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              if (onEdit != null)
                IconButton(
                  icon: Icon(
                    Icons.edit,
                    size: 18.r,
                    color: Theme.of(context).primaryColor,
                  ),
                  onPressed: onEdit,
                ),
            ],
          ),
          SizedBox(height: 8.h),
          child,
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? color,
    bool showArrow = true,
    Widget? trailing,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: (color ?? const Color(0xFFF97316)).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color ?? const Color(0xFFF97316), size: 20.r),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15.sp,
          fontWeight: FontWeight.w600,
          color: color ?? const Color(0xFF0F172A),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(fontSize: 12.sp, color: const Color(0xFF64748B)),
            )
          : null,
      trailing:
          trailing ??
          (showArrow
              ? Icon(
                  Icons.chevron_right,
                  size: 20.r,
                  color: const Color(0xFF94A3B8),
                )
              : null),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
    );
  }
}
