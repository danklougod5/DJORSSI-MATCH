import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/tag_normalizer.dart';

class JobAlertsScreen extends StatefulWidget {
  const JobAlertsScreen({super.key});

  @override
  State<JobAlertsScreen> createState() => _JobAlertsScreenState();
}

class _JobAlertsScreenState extends State<JobAlertsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPremium = false;
  bool _alertsEnabled = true;
  final Set<String> _selectedSectors = {};
  Map<String, int> _sectorCounts = {};
  Map<String, int> _jobTagCounts = {};
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<String> _availableSectors = [];

  @override
  void initState() {
    super.initState();
    _loadAlertsAndProfile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadAlertsAndProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Fetch dynamic tags
      try {
        final tagsResponse = await _supabase
            .from('jobs')
            .select('tags')
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () =>
                  throw Exception('Délai d\'attente dépassé (secteurs)'),
            );
        final List<String> rawTags = [];
        final Map<String, int> jobCounts = {};
        for (var row in tagsResponse as List) {
          if (row['tags'] != null) {
            final tags = List<String>.from(row['tags']);
            rawTags.addAll(tags);
            for (var tag in tags) {
              final normalized = TagNormalizer.normalizeDisplay(tag);
              jobCounts[normalized] = (jobCounts[normalized] ?? 0) + 1;
            }
          }
        }
        final uniqueTags = TagNormalizer.deduplicateTags(rawTags).toSet();
        _jobTagCounts = jobCounts;
        
        final profilesResponse = await _supabase
            .from('profiles')
            .select('skills')
            .limit(1000);

        final Map<String, int> rawSectorCounts = {};
        for (var row in profilesResponse as List) {
          if (row['skills'] != null) {
            for (var skill in List<String>.from(row['skills'])) {
              if (skill.isNotEmpty) {
                final normalized = TagNormalizer.normalizeDisplay(skill);
                rawSectorCounts[normalized] = (rawSectorCounts[normalized] ?? 0) + 1;
              }
            }
          }
        }
        final sectorCounts = rawSectorCounts;

        final List<String> sortedTags = uniqueTags.toList();
        sortedTags.sort((a, b) {
          final countA = sectorCounts[a] ?? 0;
          final countB = sectorCounts[b] ?? 0;
          if (countA != countB) {
            return countB.compareTo(countA); // Descending count
          }
          return a.compareTo(b); // Alphabetical
        });

        _availableSectors = sortedTags;
        _sectorCounts = sectorCounts;
      } catch (e) {
        debugPrint('Erreur lors du chargement des tags dynamiques: $e');
      }

      // 2. Check if user is premium (with expiration check)
      final profile = await _supabase
          .from('profiles')
          .select('is_premium, premium_until, skills')
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null) {
        final isPremium = profile['is_premium'] ?? false;
        final premiumUntilRaw = profile['premium_until'];
        if (isPremium && premiumUntilRaw != null) {
          final premiumUntil = DateTime.parse(premiumUntilRaw);
          _isPremium = premiumUntil.isAfter(DateTime.now());
        } else {
          _isPremium = isPremium;
        }
      }

      // 3. Load alerts
      final response = await _supabase
          .from('job_alerts')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _alertsEnabled = response['is_active'] ?? true;
          final sectors = List<String>.from(response['sectors'] ?? []);
          for (var s in sectors) {
            final match = _availableSectors.cast<String?>().firstWhere(
              (sector) => sector != null && TagNormalizer.normalizeKey(sector) == TagNormalizer.normalizeKey(s),
              orElse: () => null,
            );
            if (match != null) _selectedSectors.add(match);
          }

          if (_selectedSectors.isEmpty &&
              profile != null &&
              profile['skills'] != null) {
            for (var s in List<String>.from(profile['skills'])) {
              if (_availableSectors.contains(s)) _selectedSectors.add(s);
            }
          }
        });
      } else if (profile != null && profile['skills'] != null) {
        setState(() {
          final profileSkills = List<String>.from(profile['skills']);
          for (var s in profileSkills) {
            final match = _availableSectors.cast<String?>().firstWhere(
              (sector) => sector != null && TagNormalizer.normalizeKey(sector) == TagNormalizer.normalizeKey(s),
              orElse: () => null,
            );
            if (match != null) _selectedSectors.add(match);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading alerts: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAlerts() async {
    if (!_isPremium) return;

    setState(() => _isSaving = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('job_alerts').upsert({
        'user_id': user.id,
        'is_active': _alertsEnabled,
        'sectors': _selectedSectors.toList(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paramètres d\'alertes enregistrés !'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving alerts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'enregistrement : $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// Secteurs filtrés par la recherche
  List<String> get _filteredSectors {
    if (_searchQuery.isEmpty) return [];
    final q = _searchQuery.toLowerCase().trim();
    return _availableSectors
        .where((s) => s.toLowerCase().contains(q))
        .toList();
  }

  /// Top secteurs populaires (count > 0, max 10)
  List<String> get _popularSectors {
    return _availableSectors
        .where((tag) => (_sectorCounts[tag] ?? 0) > 0)
        .take(10)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Alertes Emplois',
          style: TextStyle(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: (_isLoading || !_isPremium)
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(
                24.w,
                12.h,
                24.w,
                MediaQuery.of(context).padding.bottom + 16.h,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: _buildSaveButton(),
            ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF97316)),
            )
          : Stack(
              children: [
                GestureDetector(
                  onTap: () => _searchFocus.unfocus(),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNotificationToggle(),
                        SizedBox(height: 32.h),

                        // Mes secteurs sélectionnés
                        if (_selectedSectors.isNotEmpty) ...[
                          _buildSelectedSectorsSection(),
                          SizedBox(height: 24.h),
                        ],

                        Text(
                          'Secteurs d\'intérêt',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Recherchez ou choisissez parmi les plus populaires.',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // Barre de recherche
                        _buildSearchBar(),
                        SizedBox(height: 20.h),

                        // Résultats de recherche ou populaires
                        _availableSectors.isEmpty
                            ? const Text(
                                "Aucun secteur disponible pour le moment.",
                                style: TextStyle(color: Colors.grey),
                              )
                            : _buildSectorsContent(),

                        SizedBox(height: 20.h),
                      ],
                    ),
                  ),
                ),
                if (!_isPremium) _buildPremiumLocker(),
              ],
            ),
    );
  }

  /// Barre de recherche stylée
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: _searchQuery.isNotEmpty
              ? const Color(0xFFF97316)
              : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: TextStyle(fontSize: 14.sp, color: const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Rechercher un secteur...',
          hintStyle: TextStyle(
            color: const Color(0xFF94A3B8),
            fontSize: 14.sp,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: _searchQuery.isNotEmpty
                ? const Color(0xFFF97316)
                : const Color(0xFF94A3B8),
            size: 22.r,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: const Color(0xFF94A3B8),
                    size: 20.r,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _searchFocus.unfocus();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 14.h,
          ),
        ),
      ),
    );
  }

  /// Contenu principal : résultats de recherche ou populaires
  Widget _buildSectorsContent() {
    // Mode recherche
    if (_searchQuery.isNotEmpty) {
      final results = _filteredSectors;
      if (results.isEmpty) {
        return Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            children: [
              Icon(Icons.search_off_rounded, size: 40.r, color: const Color(0xFF94A3B8)),
              SizedBox(height: 12.h),
              Text(
                'Aucun secteur trouvé pour "$_searchQuery"',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${results.length} résultat${results.length > 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 12.sp,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 10.h,
            children: results.map((sector) {
              final count = _sectorCounts[sector] ?? 0;
              return count > 0
                  ? _buildPopularChip(sector)
                  : _buildSimpleChip(sector);
            }).toList(),
          ),
        ],
      );
    }

    // Mode par défaut : populaires seulement
    final popular = _popularSectors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (popular.isNotEmpty) ...[
          Row(
            children: [
              Text('🔥', style: TextStyle(fontSize: 18.sp)),
              SizedBox(width: 6.w),
              Text(
                'Les plus choisis',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFF97316),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 10.h,
            children: popular.map((sector) => _buildPopularChip(sector)).toList(),
          ),
          SizedBox(height: 24.h),
          // NOUVELLE SECTION : OPPORTUNITÉS (Jobs disponibles)
          () {
            final highDemandTags = _availableSectors
                .where((tag) =>
                    !_selectedSectors.contains(tag) &&
                    (_jobTagCounts[tag] ?? 0) > 1)
                .toList();
            highDemandTags.sort((a, b) => (_jobTagCounts[b] ?? 0).compareTo(_jobTagCounts[a] ?? 0));
            final topOpportunities = highDemandTags.take(6).toList();
            
            if (topOpportunities.isEmpty) return const SizedBox.shrink();
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '💼',
                      style: TextStyle(fontSize: 18.sp),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'Top opportunités (Offres)',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0EA5E9),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 10.h,
                  children: topOpportunities
                      .map((tag) => _buildOpportunityChip(tag))
                      .toList(),
                ),
                SizedBox(height: 12.h),
              ],
            );
          }(),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18.r, color: const Color(0xFF64748B)),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Utilisez la barre de recherche pour trouver d\'autres secteurs.',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (popular.isEmpty)
          const Text(
            "Aucun secteur populaire pour le moment.",
            style: TextStyle(color: Colors.grey),
          ),
      ],
    );
  }

  /// Section "Mes secteurs sélectionnés" en haut
  Widget _buildSelectedSectorsSection() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFFF97316).withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF97316).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: const Color(0xFF22C55E), size: 20.r),
              SizedBox(width: 8.w),
              Text(
                'Mes alertes (${_selectedSectors.length})',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: _selectedSectors.map((sector) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100.r),
                  border: Border.all(
                    color: const Color(0xFFF97316).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sector,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFEA580C),
                      ),
                    ),
                    if (_isPremium && _alertsEnabled) ...[
                      SizedBox(width: 4.w),
                      GestureDetector(
                        onTap: () => setState(() => _selectedSectors.remove(sector)),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14.r,
                          color: const Color(0xFFF97316),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleChip(String sector) {
    final isSelected = _selectedSectors.contains(sector);
    return FilterChip(
      label: Text(sector),
      selected: isSelected,
      onSelected: (_isPremium && _alertsEnabled)
          ? (val) {
              setState(() {
                if (val) {
                  _selectedSectors.add(sector);
                } else {
                  _selectedSectors.remove(sector);
                }
              });
            }
          : null,
      selectedColor: const Color(0xFFF97316).withValues(alpha: 0.15),
      checkmarkColor: const Color(0xFFF97316),
      labelStyle: TextStyle(
        color: isSelected
            ? const Color(0xFFF97316)
            : const Color(0xFF64748B),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13.sp,
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(100.r),
        side: BorderSide(
          color: isSelected
              ? const Color(0xFFF97316)
              : const Color(0xFFE2E8F0),
          width: isSelected ? 1.5 : 1,
        ),
      ),
    );
  }

  Widget _buildOpportunityChip(String tag) {
    final count = _jobTagCounts[tag] ?? 0;
    final isSelected = _selectedSectors.contains(tag);
    return GestureDetector(
      onTap: (_isPremium && _alertsEnabled)
          ? () => setState(
                () => isSelected ? _selectedSectors.remove(tag) : _selectedSectors.add(tag),
              )
          : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    const Color(0xFF0EA5E9),
                    const Color(0xFF0EA5E9).withValues(alpha: 0.8),
                  ],
                )
              : const LinearGradient(
                  colors: [Color(0xFFF0F9FF), Color(0xFFE0F2FE)],
                ),
          borderRadius: BorderRadius.circular(100.r),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0EA5E9)
                : const Color(0xFF0EA5E9).withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0EA5E9).withValues(alpha: isSelected ? 0.25 : 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Padding(
                padding: EdgeInsets.only(right: 6.w),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 16.r,
                ),
              ),
            Flexible(
              child: Text(
                tag,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF0369A1),
                  fontWeight: FontWeight.w700,
                  fontSize: 13.sp,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                '$count jobs',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.white : const Color(0xFF0369A1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumLocker() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          margin: EdgeInsets.all(32.w),
          padding: EdgeInsets.all(32.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(20.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_rounded,
                  color: const Color(0xFFF97316),
                  size: 48.r,
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                'Fonctionnalité Premium',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              Text(
                'Les alertes emploi par email sont réservées aux membres Premium. Ne ratez plus aucune opportunité !',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push('/premium'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'PASSER AU PREMIUM',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14.sp,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Plus tard',
                  style: TextStyle(
                    color: const Color(0xFF94A3B8),
                    fontSize: 13.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationToggle() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: const Color(0xFFF97316),
              size: 24.r,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activer les alertes',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Recevez un email quand un job correspond',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _alertsEnabled,
            activeTrackColor: const Color(0xFFF97316),
            onChanged: _isPremium
                ? (val) => setState(() => _alertsEnabled = val)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPopularChip(String tag) {
    final count = _sectorCounts[tag] ?? 0;
    final isSelected = _selectedSectors.contains(tag);
    return GestureDetector(
      onTap: (_isPremium && _alertsEnabled)
          ? () {
              setState(() {
                if (isSelected) {
                  _selectedSectors.remove(tag);
                } else {
                  _selectedSectors.add(tag);
                }
              });
            }
          : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    const Color(0xFFF97316),
                    const Color(0xFFF97316).withValues(alpha: 0.8),
                  ],
                )
              : const LinearGradient(
                  colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
                ),
          borderRadius: BorderRadius.circular(100.r),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF97316)
                : const Color(0xFFF97316).withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF97316).withValues(alpha: isSelected ? 0.25 : 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Padding(
                padding: EdgeInsets.only(right: 6.w),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 16.r,
                ),
              ),
            Flexible(
              child: Text(
                tag,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFFEA580C),
                  fontWeight: FontWeight.w700,
                  fontSize: 13.sp,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFFF97316).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.white : const Color(0xFFF97316),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_isSaving || !_isPremium) ? null : _saveAlerts,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 20.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'ENREGISTRER LES PRÉFÉRENCES',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }
}
