import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/version_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:in_app_review/in_app_review.dart';
import '../../../core/cache/local_cache.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  List<String> _skills = [];
  String? _fullName;
  int _unreadSupportReplies = 0;

  StreamSubscription<List<Map<String, dynamic>>>? _profileSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
    _setupRealtime();
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _profileSubscription?.cancel();
    super.dispose();
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
          .select('id, full_name, skills, cv_url, is_premium, premium_until, sexe')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        // Mettre en cache
        await LocalCache.save(LocalCache.profileKey, response);
        
        if (mounted) {
          setState(() {
            _profileData = response;
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

  /// Navigue vers l'écran d'édition et recharge le profil au retour
  Future<void> _navigateToEditProfile() async {
    final result = await context.push('/complete-profile');
    // Si le profil a été modifié, recharger les données
    if (result == true && mounted) {
      _loadProfile(forceRefresh: true);
    }
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
      await _supabase.auth.signOut();
      if (mounted) {
        context.go('/auth');
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Supprimer mon compte',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Cette action est irréversible. Toutes vos candidatures, vos matches et vos informations personnelles seront définitivement supprimés.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Supprimer définitivement',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
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
    final contactInfo = user?.phone ?? user?.email ?? 'Contact non disponible';

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
                            color: (_profileData?['is_premium'] ?? false)
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
                          child: Icon(
                            Icons.person,
                            size: 60.r,
                            color: (_profileData?['is_premium'] ?? false)
                                ? const Color(0xFFF59E0B).withOpacity(0.5)
                                : const Color(0xFF94A3B8),
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
                  SizedBox(height: 20.h),
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
                      if (_profileData?['is_premium'] ?? false)
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
                      gradient: (_profileData?['is_premium'] ?? false)
                          ? const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                            )
                          : null,
                      color: (_profileData?['is_premium'] ?? false)
                          ? null
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: (_profileData?['is_premium'] ?? false)
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
                        if (_profileData?['is_premium'] ?? false)
                          Padding(
                            padding: EdgeInsets.only(right: 6.w),
                            child: Icon(
                              Icons.workspace_premium,
                              color: Colors.white,
                              size: 14.r,
                            ),
                          ),
                        Text(
                          (_profileData?['is_premium'] ?? false)
                              ? 'MEMBRE VIP'
                              : 'Utilisateur Freemium',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing:
                                (_profileData?['is_premium'] ?? false) ? 1 : 0,
                            color: (_profileData?['is_premium'] ?? false)
                                ? Colors.white
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    contactInfo,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32.h),

            // Premium Banner
            _buildPremiumBanner(),

            SizedBox(height: 16.h),

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
                    trailing: (VersionService.showPremium && !(_profileData?['is_premium'] ?? false))
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
                    onTap: () => context.push('/job-alerts'),
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
    final isPremium = _profileData?['is_premium'] ?? false;
    
    // Si le mode Premium est désactivé à distance (pour la validation Apple)
    // et que l'utilisateur n'est pas déjà premium, on cache la bannière.
    if (!VersionService.showPremium && !isPremium) {
      return const SizedBox.shrink();
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
                        isPremium
                            ? 'Tous vos avantages sont activés ✓'
                            : 'Boostez votre profil et matchez plus vite !',
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
