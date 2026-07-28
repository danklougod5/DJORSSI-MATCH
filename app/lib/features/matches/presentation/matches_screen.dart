import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/version_service.dart';
import 'package:djossimatch/core/cache/local_cache.dart';
import 'package:djossimatch/core/services/match_notifier.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isPremium = false;
  List<Map<String, dynamic>> _matches = [];

  String _selectedFilter = 'Tous';
  StreamSubscription<List<Map<String, dynamic>>>? _profileSubscription;

  @override
  void initState() {
    super.initState();
    _loadPremiumFromCache(); // Restaurer le statut premium immédiatement
    _loadMatches();
    MatchNotifier.stream.addListener(_onNewMatch);
    _setupRealtime();
  }

  /// Charge le statut premium depuis le cache du profil pour éviter
  /// un flash de contenu verrouillé au démarrage.
  Future<void> _loadPremiumFromCache() async {
    try {
      final cachedProfile = await LocalCache.load(LocalCache.profileKey);
      if (cachedProfile != null && cachedProfile is Map<String, dynamic> && mounted) {
        final isPremium = cachedProfile['is_premium'] ?? false;
        final premiumUntilRaw = cachedProfile['premium_until'];
        bool activePremium = isPremium;
        if (isPremium && premiumUntilRaw != null) {
          final premiumUntil = DateTime.parse(premiumUntilRaw.toString());
          activePremium = premiumUntil.isAfter(DateTime.now());
        }
        if (!VersionService.showPremium) {
          activePremium = true;
        }
        setState(() {
          _isPremium = activePremium;
        });
      }
    } catch (e) {
      debugPrint('MatchesScreen: erreur lecture cache premium: $e');
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
            final profile = data.first;
            final isPremium = profile['is_premium'] ?? false;
            final premiumUntilRaw = profile['premium_until'];
            bool activePremium = isPremium;
            if (isPremium && premiumUntilRaw != null) {
              final premiumUntil = DateTime.parse(premiumUntilRaw);
              activePremium = premiumUntil.isAfter(DateTime.now());
            }
            if (!VersionService.showPremium) {
              activePremium = true;
            }
            setState(() {
              _isPremium = activePremium;
            });
          }
        }, onError: (e) {
          debugPrint('MatchesScreen: profiles realtime error: $e');
        });
  }

  void _onNewMatch() {
    // Eviter de spammer les rechargements s'il y a de multiples événements
    if (mounted) {
      _loadMatches(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    MatchNotifier.stream.removeListener(_onNewMatch);
    _profileSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadMatches({bool forceRefresh = false}) async {
    // 0. Charger le cache immédiatement (hors ligne ou affichage rapide)
    try {
      final cachedMatches = await LocalCache.load(LocalCache.matchesKey);
      if (cachedMatches != null && cachedMatches is List && mounted) {
        setState(() {
          _matches = List<Map<String, dynamic>>.from(cachedMatches);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur lecture cache matches: $e');
    }

    // 0.5 Si le cache est frais (TTL) et qu'on ne force pas le rafraîchissement,
    // on saute le rechargement des matches MAIS on vérifie toujours le premium
    try {
      final isFresh = await LocalCache.isFresh(LocalCache.matchesKey, LocalCache.matchesTTL);
      if (isFresh && !forceRefresh) {
        debugPrint('*** [CACHE] Matches chargés depuis le cache frais (TTL) - Pas d\'appel réseau ***');
        // TOUJOURS vérifier le statut premium même si le cache matches est frais
        await _refreshPremiumStatus();
        return;
      }
    } catch (e) {
      debugPrint('Erreur vérification fraîcheur cache matches: $e');
    }

    // Sinon, charger depuis Supabase
    setState(() => _isLoading = _matches.isEmpty);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final profileResponse = await _supabase
          .from('profiles')
          .select('is_premium, premium_until')
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
      }

      if (!VersionService.showPremium) {
        _isPremium = true;
      }

      final response = await _supabase
          .from('swipes_log')
          .select('id, created_at, user_id, job_id, jobs(id, company_name, job_title, whatsapp_number, contact_email, application_link, salary_range, location, description, experience, required_level, requires_cover_letter, cover_letter_instructions)')
          .eq('user_id', userId)
          .eq('direction', 'right')
          .order('created_at', ascending: false);

      final matchesList = List<Map<String, dynamic>>.from(response);

      // Sauvegarder dans le cache
      await LocalCache.save(LocalCache.matchesKey, matchesList);

      if (mounted) {
        setState(() {
          _matches = matchesList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement réseau matches: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        if (_matches.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Mode hors-ligne : affichage des matches en cache.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  /// Rafraîchit le statut premium depuis Supabase (appel léger, un seul champ).
  Future<void> _refreshPremiumStatus() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final profileResponse = await _supabase
          .from('profiles')
          .select('is_premium, premium_until')
          .eq('id', userId)
          .maybeSingle();

      if (profileResponse != null && mounted) {
        final isPremium = profileResponse['is_premium'] ?? false;
        final premiumUntilRaw = profileResponse['premium_until'];
        bool activePremium = isPremium;
        if (isPremium && premiumUntilRaw != null) {
          final premiumUntil = DateTime.parse(premiumUntilRaw.toString());
          activePremium = premiumUntil.isAfter(DateTime.now());
        }
        if (!VersionService.showPremium) {
          activePremium = true;
        }
        setState(() {
          _isPremium = activePremium;
        });
      }
    } catch (e) {
      debugPrint('MatchesScreen: erreur refresh premium: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredMatches {
    if (_selectedFilter == 'Tous') return _matches;

    final now = DateTime.now();
    return _matches.where((match) {
      final date = DateTime.parse(match['created_at']);
      final difference = now.difference(date).inDays;

      if (_selectedFilter == 'Aujourd\'hui') {
        return difference == 0 && date.day == now.day;
      } else if (_selectedFilter == '7 derniers jours') {
        return difference <= 7;
      } else if (_selectedFilter == '30 derniers jours') {
        return difference <= 30;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFF97316)),
      );
    }

    final filtered = _filteredMatches;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Mes Matches',
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
        onRefresh: () => _loadMatches(forceRefresh: true),
        color: const Color(0xFFF97316),
        child: Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: filtered.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: 500
                            .h, // Hauteur suffisante pour permettre le scroll
                        alignment: Alignment.center,
                        child: _buildEmptyState(),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.all(16.r),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          SizedBox(height: 12.h),
                      itemBuilder: (context, index) {
                        final match = filtered[index];

                        // Limit to 3 matches if Freemium or if featUnlockedHistory is disabled
                        final isUnlocked = _isPremium && VersionService.featUnlockedHistory;
                        final isLocked = !isUnlocked && index >= 3 && VersionService.showPremium;
                        return _buildMatchCard(match, isLocked: isLocked);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      'Tous',
      'Aujourd\'hui',
      '7 derniers jours',
      '30 derniers jours',
    ];
    return Container(
      height: 60.h,
      color: Colors.white,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          return Center(
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedFilter = filter);
                }
              },
              backgroundColor: Colors.grey.shade50,
              selectedColor: const Color(0xFFF97316).withOpacity(0.1),
              labelStyle: TextStyle(
                color: isSelected
                    ? const Color(0xFFF97316)
                    : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13.sp,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFFF97316)
                      : Colors.grey.shade200,
                  width: 1,
                ),
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80.r, color: Colors.grey.shade300),
          SizedBox(height: 16.h),
          Text(
            _selectedFilter == 'Tous'
                ? 'Aucun match pour le moment'
                : 'Aucun match pour cette période',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            _selectedFilter == 'Tous'
                ? 'Continuez à swiper pour trouver votre Djorssi !'
                : 'Essayez un autre filtre ou continuez à swiper.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match, {bool isLocked = false}) {
    final job = match['jobs'];
    final date = DateTime.parse(match['created_at']);

    // Display correct status badge based on job apply type
    final whatsapp = job?['whatsapp_number'];
    final email = job?['contact_email'];
    final appLink =
        job?['application_link'] ??
        (job?['raw_data'] != null
            ? job!['raw_data']['application_link']
            : null);

    final hasEmail = email != null && email.toString().trim().isNotEmpty;
    final hasWhatsapp =
        whatsapp != null && whatsapp.toString().trim().isNotEmpty;
    final hasLink = appLink != null && appLink.toString().trim().isNotEmpty;

    final actionTaken = match['status'] == 'action_taken';

    String badgeText = 'CV Envoyé';
    if (!hasEmail) {
      if (hasWhatsapp) {
        badgeText = actionTaken ? 'Contacté sur WA' : 'À contacter';
      } else if (hasLink) {
        badgeText = actionTaken ? 'Lien visité' : 'Lien Externe';
      } else {
        badgeText = 'Profil envoyé';
      }
    }

    if (isLocked) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: const Color(0xFFF59E0B).withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: InkWell(
          onTap: () => context.push('/premium').then((_) {
            if (mounted) {
              _loadMatches(forceRefresh: true);
            }
          }),
          child: Padding(
            padding: EdgeInsets.all(20.r),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 24.r,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ancien Match Bloqué',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Passez au Premium pour voir tout votre historique.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: InkWell(
          onTap: () {
            context.push('/match-details', extra: {'match': match});
          },
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Row(
              children: [
                Container(
                  width: 60.r,
                  height: 60.r,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Center(
                    child: Text(
                      ((job?['company_name']?.toString().isNotEmpty == true)
                              ? job!['company_name'].toString()[0]
                              : 'C')
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF97316),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job?['job_title'] ?? 'Inconnu',
                        style: TextStyle(
                          fontSize: 15
                              .sp, // Slightly reduced to prevent wrapping issues
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                          height: 1.3, // Prevents text overlapping vertically
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        job?['company_name'] ?? 'Inconnu',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey.shade600,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 12.r,
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Matché le ${DateFormat('dd/MM/yyyy').format(date)}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: const Color(0xFFF97316),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
