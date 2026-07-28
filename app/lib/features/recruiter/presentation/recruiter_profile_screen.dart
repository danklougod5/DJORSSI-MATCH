import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:djossimatch/features/recruiter/presentation/widgets/candidate_cv_swipe_card.dart';
import 'package:djossimatch/core/cache/local_cache.dart';

class RecruiterProfileScreen extends StatefulWidget {
  const RecruiterProfileScreen({super.key});

  @override
  State<RecruiterProfileScreen> createState() => _RecruiterProfileScreenState();
}

class _RecruiterProfileScreenState extends State<RecruiterProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _jobsRealtimeChannel;

  bool _isLoadingProfile = true;
  bool _isLoadingJobs = true;
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _myJobs = [];
  DateTime _lastRealtimeJobsReload = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadMyJobs();
    _setupJobsRealtime();
  }

  void _setupJobsRealtime() {
    final recruiterId = _supabase.auth.currentUser?.id;
    if (recruiterId == null) return;

    _jobsRealtimeChannel = _supabase
        .channel('public:recruiter_profile_jobs:$recruiterId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'jobs',
          callback: (payload) => _handleJobRealtimeChange(
            recruiterId: recruiterId,
            newRecord: payload.newRecord,
            oldRecord: payload.oldRecord,
          ),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'jobs',
          callback: (payload) => _handleJobRealtimeChange(
            recruiterId: recruiterId,
            newRecord: payload.newRecord,
            oldRecord: payload.oldRecord,
          ),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'jobs',
          callback: (payload) => _handleJobRealtimeChange(
            recruiterId: recruiterId,
            newRecord: payload.newRecord,
            oldRecord: payload.oldRecord,
          ),
        );

    _jobsRealtimeChannel!.subscribe();
  }

  void _handleJobRealtimeChange({
    required String recruiterId,
    required Map<String, dynamic> newRecord,
    required Map<String, dynamic> oldRecord,
  }) {
    final changedRecruiterId =
        (newRecord['recruiter_id'] ?? oldRecord['recruiter_id'])?.toString();
    if (changedRecruiterId != recruiterId || !mounted) return;

    final now = DateTime.now();
    if (now.difference(_lastRealtimeJobsReload).inMilliseconds < 800) {
      return;
    }
    _lastRealtimeJobsReload = now;
    _loadMyJobs();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _profileData = response;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading recruiter profile: $e');
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  Future<void> _loadMyJobs() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('jobs')
          .select('*')
          .eq('recruiter_id', user.id)
          .order('created_at', ascending: false);

      final jobs = List<Map<String, dynamic>>.from(response);

      // Count candidatures (right-swipes) per job
      if (jobs.isNotEmpty) {
        final jobIds = jobs.map((j) => j['id'] as String).toList();
        final swipesResponse = await _supabase
            .from('swipes_log')
            .select('job_id')
            .inFilter('job_id', jobIds)
            .eq('direction', 'right');
        final swipes = List<Map<String, dynamic>>.from(swipesResponse);
        final Map<String, int> countByJob = {};
        for (var s in swipes) {
          final jid = s['job_id'] as String;
          countByJob[jid] = (countByJob[jid] ?? 0) + 1;
        }
        for (var job in jobs) {
          job['applications'] = List.generate(
            countByJob[job['id']] ?? 0,
            (i) => {'index': i},
          );
        }
      }

      if (mounted) {
        setState(() {
          _myJobs = jobs;
          _isLoadingJobs = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading recruiter jobs: $e');
      if (mounted) {
        setState(() => _isLoadingJobs = false);
      }
    }
  }

  Future<void> _loadApplicationsForJob(Map<String, dynamic> job) async {
    try {
      // Fetch right-swipes on this job from swipes_log
      final swipesResponse = await _supabase
          .from('swipes_log')
          .select('id, created_at, user_id')
          .eq('job_id', job['id'])
          .eq('direction', 'right')
          .order('created_at', ascending: false);

      final swipes = List<Map<String, dynamic>>.from(swipesResponse);

      // Fetch profiles for those candidates
      final candidateIds = swipes
          .map((s) => s['user_id'] as String)
          .toSet()
          .toList();
      Map<String, Map<String, dynamic>> profilesMap = {};
      if (candidateIds.isNotEmpty) {
        final profilesResponse = await _supabase
            .from('profiles')
            .select(
              'id, full_name, cv_url, skills, biography, sexe, phone_number',
            )
            .inFilter('id', candidateIds);
        for (var p in (profilesResponse as List)) {
          profilesMap[p['id']] = Map<String, dynamic>.from(p);
        }
      }

      // Build applications list with profile data
      final applications = swipes.map((s) {
        final profile = profilesMap[s['user_id']];
        return {
          'id': s['id'],
          'created_at': s['created_at'],
          'user_id': s['user_id'],
          'status': 'pending',
          'profiles': profile,
        };
      }).toList();

      if (mounted) {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _JobApplicantsScreen(
              job: job,
              applications: applications,
              onChatTap: _initiateChatAndNavigate,
              onJobUpdated: _loadMyJobs,
            ),
          ),
        );

        if ((result == true || result == 'deleted') && mounted) {
          setState(() {
            _myJobs.removeWhere((j) => j['id'] == job['id']);
          });
          await _loadMyJobs();
        }
      }
    } catch (e) {
      debugPrint('Error loading job applications: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors du chargement des candidatures.'),
          ),
        );
      }
    }
  }

  Future<void> _initiateChatAndNavigate(
    BuildContext context,
    String candidateId,
    String candidateName,
  ) async {
    try {
      final recruiterId = _supabase.auth.currentUser?.id;
      if (recruiterId == null) return;

      final response = await _supabase
          .from('recruiter_candidate_chats')
          .upsert({
            'recruiter_id': recruiterId,
            'candidate_id': candidateId,
          }, onConflict: 'recruiter_id,candidate_id')
          .select('id')
          .single();

      final chatId = response['id'] as String;

      if (context.mounted) {
        context.push(
          '/chat/$chatId',
          extra: {
            'otherUserName': candidateName,
            'otherUserCompany': null,
            'isRecruiter': true,
          },
        );
      }
    } catch (e) {
      debugPrint('Error initiating chat from profile: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'initier la discussion.')),
        );
      }
    }
  }

  String _maskEmail(String email) {
    if (email.isEmpty) return '—';
    final parts = email.split('@');
    if (parts.length != 2) return '••••@••••';
    final name = parts[0];
    final domain = parts[1];
    final visibleChars = name.length > 2 ? 2 : 1;
    return '${name.substring(0, visibleChars)}${'•' * (name.length - visibleChars)}@$domain';
  }

  static const List<String> _sectors = [
    'Informatique',
    'Commerce & Management',
    'Finance & Comptabilité',
    'BTP & Industrie',
    'Logistique & Transport',
    'Santé & Social',
    'Éducation & Formation',
    'Hôtellerie & Restauration',
    'Sécurité & Gardiennage',
    'Juridique & Droit',
    'Polyvalent / Tout Secteur',
  ];

  void _showEditProfileSheet() {
    final nameCtrl = TextEditingController(
      text: _profileData?['full_name'] ?? '',
    );
    final companyCtrl = TextEditingController(
      text: _profileData?['company_name'] ?? '',
    );
    final sizeCtrl = TextEditingController(
      text: _profileData?['company_size']?.toString() ?? '',
    );
    final String? currentIndustry = _profileData?['company_industry'];
    String? selectedSector = _sectors.contains(currentIndustry)
        ? currentIndustry
        : null;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                24.w,
                12.h,
                24.w,
                MediaQuery.of(ctx).viewInsets.bottom + 24.h,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40.w,
                        height: 4.h,
                        margin: EdgeInsets.only(bottom: 20.h),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                    ),
                    Text(
                      'Modifier le profil',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    _buildEditField(
                      nameCtrl,
                      'Nom du responsable',
                      Icons.person_rounded,
                    ),
                    SizedBox(height: 14.h),
                    _buildEditField(
                      companyCtrl,
                      'Nom de l\'entreprise',
                      Icons.business_rounded,
                    ),
                    SizedBox(height: 14.h),
                    DropdownButtonFormField<String>(
                      value: selectedSector,
                      items: _sectors.map((sector) {
                        return DropdownMenuItem<String>(
                          value: sector,
                          child: Text(
                            sector,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setSheetState(() {
                          selectedSector = val;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: "Secteur d'activité",
                        prefixIcon: Icon(
                          Icons.category_rounded,
                          color: const Color(0xFF1E3A8A),
                          size: 20.r,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: const BorderSide(
                            color: Color(0xFF1E3A8A),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 14.h,
                        ),
                      ),
                    ),
                    SizedBox(height: 14.h),
                    _buildEditField(
                      sizeCtrl,
                      'Nombre d\'employés',
                      Icons.people_rounded,
                      isNumber: true,
                    ),
                    SizedBox(height: 28.h),
                    SizedBox(
                      width: double.infinity,
                      height: 52.h,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                setSheetState(() => isSaving = true);
                                try {
                                  final userId = _supabase.auth.currentUser?.id;
                                  if (userId == null) return;
                                  await _supabase
                                      .from('profiles')
                                      .update({
                                        'full_name': nameCtrl.text.trim(),
                                        'company_name': companyCtrl.text.trim(),
                                        'company_industry':
                                            selectedSector ?? '',
                                        'company_size': sizeCtrl.text.trim(),
                                      })
                                      .eq('id', userId);
                                  if (mounted) {
                                    Navigator.pop(ctx);
                                    _loadProfile(); // Reload
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Profil mis à jour ✓'),
                                        backgroundColor: Color(0xFF22C55E),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  debugPrint('Error updating profile: $e');
                                  setSheetState(() => isSaving = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Erreur lors de la mise à jour.',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          textStyle: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: isSaving
                            ? SizedBox(
                                width: 22.r,
                                height: 22.r,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text('Enregistrer les modifications'),
                      ),
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

  Widget _buildEditField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1E3A8A), size: 20.r),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
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

  @override
  void dispose() {
    if (_jobsRealtimeChannel != null) {
      _supabase.removeChannel(_jobsRealtimeChannel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
        ),
      );
    }

    final companyName = _profileData?['company_name'] ?? 'Mon Entreprise';
    final industry = _profileData?['company_industry'] ?? '';
    final fullName = _profileData?['full_name'] ?? '';
    final companySize = _profileData?['company_size']?.toString() ?? '';
    final email = _supabase.auth.currentUser?.email ?? '';
    final maskedEmail = _maskEmail(email);
    final initial = companyName.isNotEmpty ? companyName[0].toUpperCase() : 'E';
    // Hide industry in badge if it looks like a password (contains special chars)
    final showIndustryBadge =
        industry.isNotEmpty && !industry.contains('@') && industry.length > 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadProfile();
          await _loadMyJobs();
        },
        color: const Color(0xFF1E3A8A),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ─── HERO HEADER ───
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0F172A),
                      Color(0xFF1E3A8A),
                      Color(0xFF1D4ED8),
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h),
                    child: Column(
                      children: [
                        // Top bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Mon Profil',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            GestureDetector(
                              onTap: _signOut,
                              child: Container(
                                padding: EdgeInsets.all(8.r),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Icon(
                                  Icons.logout_rounded,
                                  color: Colors.white70,
                                  size: 20.r,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 28.h),

                        // Company Avatar
                        Container(
                          width: 80.r,
                          height: 80.r,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: TextStyle(
                                fontSize: 32.sp,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF1E3A8A),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // Company Name
                        Text(
                          companyName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        if (showIndustryBadge) ...[
                          SizedBox(height: 6.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 5.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              industry,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: 20.h),

                        // Stats row
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 14.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatItem(
                                _isLoadingJobs ? '...' : '${_myJobs.length}',
                                'Offres',
                                Icons.work_outline_rounded,
                              ),
                              Container(
                                width: 1,
                                height: 36.h,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              _buildStatItem(
                                _isLoadingJobs
                                    ? '...'
                                    : '${_myJobs.fold<int>(0, (sum, job) => sum + ((job['applications'] as List?)?.length ?? 0))}',
                                  'Swipes',
                                Icons.people_outline_rounded,
                              ),
                              Container(
                                width: 1,
                                height: 36.h,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              _buildStatItem(
                                companySize.isNotEmpty ? companySize : '—',
                                'Employés',
                                Icons.groups_outlined,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ─── COMPANY INFO CARD ───
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 0),
                child: Container(
                  padding: EdgeInsets.all(20.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
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
                          Icon(
                            Icons.business_rounded,
                            color: const Color(0xFF1E3A8A),
                            size: 20.r,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              'Informations',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _showEditProfileSheet,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 6.h,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF1E3A8A,
                                ).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_rounded,
                                    size: 14.r,
                                    color: const Color(0xFF1E3A8A),
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'Modifier',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E3A8A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      _buildInfoTile(
                        Icons.person_rounded,
                        'Responsable',
                        fullName.isNotEmpty ? fullName : '—',
                      ),
                      _buildInfoTile(Icons.mail_rounded, 'E-mail', maskedEmail),
                      _buildInfoTile(
                        Icons.category_rounded,
                        'Secteur',
                        showIndustryBadge ? industry : '—',
                      ),
                      _buildInfoTile(
                        Icons.people_rounded,
                        'Taille',
                        companySize.isNotEmpty ? '$companySize employés' : '—',
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ─── MY JOBS SECTION ───
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 8.h),
                child: Row(
                  children: [
                    Icon(
                      Icons.list_alt_rounded,
                      color: const Color(0xFF1E3A8A),
                      size: 20.r,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Mes offres publiées',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    if (!_isLoadingJobs && _myJobs.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          '${_myJobs.length}',
                          style: TextStyle(
                            color: const Color(0xFF1E3A8A),
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            if (_isLoadingJobs)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
                ),
              )
            else if (_myJobs.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24.r),
                  child: Container(
                    padding: EdgeInsets.all(32.r),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.post_add_rounded,
                          size: 48.r,
                          color: Colors.grey.shade300,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'Aucune offre publiée',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                            'Publiez une offre pour suivre les personnes intéressées.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final job = _myJobs[index];
                  final appCount = (job['applications'] as List?)?.length ?? 0;
                  final isApproved = job['is_approved'] == true;

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 6.h,
                    ),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      elevation: 0,
                        child: InkWell(
                          onTap: () => _showJobDetailsModalFromProfile(context, job),
                        borderRadius: BorderRadius.circular(16.r),
                        child: Container(
                          padding: EdgeInsets.all(16.r),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              // Job icon
                              Container(
                                width: 48.r,
                                height: 48.r,
                                decoration: BoxDecoration(
                                  color: appCount > 0
                                      ? const Color(
                                          0xFF22C55E,
                                        ).withValues(alpha: 0.1)
                                      : const Color(
                                          0xFF1E3A8A,
                                        ).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                                child: Icon(
                                  appCount > 0
                                      ? Icons.people_alt_rounded
                                      : Icons.work_rounded,
                                  color: appCount > 0
                                      ? const Color(0xFF22C55E)
                                      : const Color(0xFF1E3A8A),
                                  size: 22.r,
                                ),
                              ),
                              SizedBox(width: 14.w),

                              // Job Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      job['job_title'] ?? 'Poste',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          size: 13.r,
                                          color: Colors.grey.shade500,
                                        ),
                                        SizedBox(width: 3.w),
                                        Text(
                                          job['location'] ?? 'Abidjan',
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                        SizedBox(width: 12.w),
                                        Container(
                                          width: 4.r,
                                          height: 4.r,
                                          decoration: BoxDecoration(
                                            color: isApproved
                                                ? const Color(0xFF22C55E)
                                                : const Color(0xFFF59E0B),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        SizedBox(width: 4.w),
                                        Text(
                                            isApproved ? 'En ligne' : 'En examen',
                                          style: TextStyle(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w600,
                                            color: isApproved
                                                ? const Color(0xFF22C55E)
                                                : const Color(0xFFF59E0B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Applicant count badge
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 8.h,
                                ),
                                decoration: BoxDecoration(
                                  color: appCount > 0
                                      ? const Color(
                                          0xFFF97316,
                                        ).withValues(alpha: 0.1)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '$appCount',
                                      style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w900,
                                        color: appCount > 0
                                            ? const Color(0xFFF97316)
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                    Text(
                                        'swipe${appCount != 1 ? "s" : ""}',
                                      style: TextStyle(
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.w600,
                                        color: appCount > 0
                                            ? const Color(0xFFF97316)
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.grey.shade300,
                                size: 20.r,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }, childCount: _myJobs.length),
              ),

            // Bottom padding
            SliverToBoxAdapter(child: SizedBox(height: 32.h)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18.r),
        SizedBox(height: 6.h),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(
    IconData icon,
    String label,
    String value, {
    bool isLast = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Container(
            width: 36.r,
            height: 36.r,
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: const Color(0xFF1E3A8A), size: 18.r),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ─── Job Applicants Detail Screen ───
class _JobApplicantsScreen extends StatelessWidget {
  final Map<String, dynamic> job;
  final List<Map<String, dynamic>> applications;
  final Future<void> Function(BuildContext, String, String) onChatTap;
  final Future<void> Function()? onJobUpdated;

  const _JobApplicantsScreen({
    required this.job,
    required this.applications,
    required this.onChatTap,
    this.onJobUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              job['job_title'] ?? 'Offre',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            Text(
              '${applications.length} candidat${applications.length > 1 ? "s" : ""}',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF0F172A)),
            onSelected: (value) {
              if (value == 'view') {
                _showJobDetailsModalFromProfile(context, job);
              } else if (value == 'edit') {
                _openEditJobModalFromProfile(
                  context,
                  job,
                  onJobUpdated: onJobUpdated,
                );
              } else if (value == 'delete') {
                _confirmDeleteJobFromProfile(context, job);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'view',
                child: Row(
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      size: 18.r,
                      color: const Color(0xFF334155),
                    ),
                    SizedBox(width: 8.w),
                    Text('Voir l\'offre', style: TextStyle(fontSize: 13.5.sp)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      size: 18.r,
                      color: const Color(0xFF334155),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Modifier l\'offre',
                      style: TextStyle(fontSize: 13.5.sp),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 18.r,
                      color: const Color(0xFFDC2626),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Supprimer',
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: applications.isEmpty
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(32.r),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_off_rounded,
                      size: 56.r,
                      color: Colors.grey.shade300,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Aucune candidature',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'Personne n\'a encore postulé à cette offre.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16.r),
              itemCount: applications.length,
              itemBuilder: (context, index) {
                final app = applications[index];
                final profile = app['profiles'] as Map<String, dynamic>?;
                if (profile == null) return const SizedBox.shrink();

                final fullName = profile['full_name'] ?? 'Candidat';
                final skills = List<String>.from(profile['skills'] ?? []);
                final bio = profile['biography'] as String? ?? '';
                final cvUrl = profile['cv_url'] as String?;
                final sexe = profile['sexe'] as String?;
                final initial = fullName.isNotEmpty
                    ? fullName[0].toUpperCase()
                    : 'C';

                return Container(
                  margin: EdgeInsets.only(bottom: 12.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          children: [
                            Container(
                              width: 48.r,
                              height: 48.r,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFF97316),
                                    Color(0xFFFB923C),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                              child: Center(
                                child: Text(
                                  initial,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fullName,
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (skills.isNotEmpty)
                                    Text(
                                      skills.take(3).join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (sexe != null)
                              Icon(
                                sexe == 'Femme' ? Icons.woman : Icons.man,
                                color: Colors.grey.shade400,
                                size: 20.r,
                              ),
                          ],
                        ),

                        if (bio.isNotEmpty) ...[
                          SizedBox(height: 12.h),
                          Text(
                            bio,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.grey.shade600,
                              height: 1.5,
                            ),
                          ),
                        ],

                        SizedBox(height: 16.h),

                        // Action buttons
                        Row(
                          children: [
                            if (cvUrl != null && cvUrl.isNotEmpty)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => FullScreenCvViewer(
                                          candidateId: profile['id'] as String?,
                                          candidateName: fullName,
                                          skills: skills,
                                          biography: bio,
                                          sexe: sexe,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: Icon(
                                    Icons.description_outlined,
                                    size: 16.r,
                                  ),
                                  label: const Text('Voir CV'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFF97316),
                                    side: const BorderSide(
                                      color: Color(0xFFF97316),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      vertical: 10.h,
                                    ),
                                  ),
                                ),
                              ),
                            if (cvUrl != null && cvUrl.isNotEmpty)
                              SizedBox(width: 10.w),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    onChatTap(context, profile['id'], fullName),
                                icon: Icon(Icons.chat_rounded, size: 16.r),
                                label: const Text('Discuter'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A8A),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 10.h),
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
            ),
    );
  }
}

void _showJobDetailsModalFromProfile(
  BuildContext context,
  Map<String, dynamic> job,
) {
  final title = job['job_title'] ?? 'Sans titre';
  final company = job['company_name'] ?? '';
  final location = job['location'] ?? 'Abidjan';
  final description = job['description'] ?? 'Aucune description disponible.';
  final salary = job['salary_range'] ?? 'Non spécifié';
  final level = job['required_level'] ?? 'Non spécifié';
  final email = job['contact_email'] ?? '';
  final whatsapp = job['whatsapp_number'] ?? '';
  final contract = job['contract_type'] ?? 'CDI';
  final rawTags = job['tags'] ?? [];
  final List<String> tags = rawTags is List ? List<String>.from(rawTags) : [];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '$company • $location',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            const Divider(color: Color(0xFFE2E8F0)),
            SizedBox(height: 12.h),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        _buildDetailBadgeStatic(
                          Icons.assignment_ind_outlined,
                          contract,
                          const Color(0xFFEFF6FF),
                          const Color(0xFF1D4ED8),
                        ),
                        _buildDetailBadgeStatic(
                          Icons.payments_outlined,
                          salary,
                          const Color(0xFFF0FDF4),
                          const Color(0xFF15803D),
                        ),
                        _buildDetailBadgeStatic(
                          Icons.school_outlined,
                          level,
                          const Color(0xFFFEF3C7),
                          const Color(0xFFB45309),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),

                    Text(
                      'Description du poste',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: const Color(0xFF334155),
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 20.h),

                    if (tags.isNotEmpty) ...[
                      Text(
                        'Mots-clés / Compétences',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 6.w,
                        runSpacing: 6.h,
                        children: tags
                            .map(
                              (t) => Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 5.h,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  t,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: const Color(0xFF475569),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      SizedBox(height: 20.h),
                    ],

                    if (email.isNotEmpty || whatsapp.isNotEmpty) ...[
                      Text(
                        'Contacts renseignés',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      if (email.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(bottom: 6.h),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.email_outlined,
                                size: 16,
                                color: Color(0xFF64748B),
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                email,
                                style: TextStyle(
                                  fontSize: 13.5.sp,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (whatsapp.isNotEmpty)
                        Row(
                          children: [
                            const Icon(
                              Icons.chat_outlined,
                              size: 16,
                              color: Color(0xFF25D366),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              whatsapp,
                              style: TextStyle(
                                fontSize: 13.5.sp,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildDetailBadgeStatic(
  IconData icon,
  String label,
  Color bg,
  Color text,
) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(8.r),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.r, color: text),
        SizedBox(width: 5.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            color: text,
          ),
        ),
      ],
    ),
  );
}

void _openEditJobModalFromProfile(
  BuildContext context,
  Map<String, dynamic> job, {
  Future<void> Function()? onJobUpdated,
}) {
  final editCompanyController = TextEditingController(
    text: job['company_name'] ?? '',
  );
  final editTitleController = TextEditingController(
    text: job['job_title'] ?? '',
  );
  final editLocationController = TextEditingController(
    text: job['location'] ?? 'Abidjan',
  );
  final editSalaryController = TextEditingController(
    text: job['salary_range'] ?? '',
  );
  final editLevelController = TextEditingController(
    text: job['required_level'] ?? '',
  );
  final editEmailController = TextEditingController(
    text: job['contact_email'] ?? '',
  );
  final editWhatsappController = TextEditingController(
    text: job['whatsapp_number'] ?? '',
  );
  final editDescriptionController = TextEditingController(
    text: job['description'] ?? '',
  );
  final customTagController = TextEditingController();
  final rawJobTags = job['tags'] ?? [];
  final Set<String> editSelectedTags = Set<String>.from(
    rawJobTags is List ? List<String>.from(rawJobTags) : [],
  );
  String editContractType = job['contract_type'] ?? 'CDI';
  bool editIsSaving = false;
  final contractTypes = [
    'CDI',
    'CDD',
    'Stage',
    'Alternance',
    'Freelance',
    'Intérim',
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                SizedBox(height: 14.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Modifier l\'offre',
                      style: TextStyle(
                        fontSize: 18.sp,
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
                const Divider(color: Color(0xFFE2E8F0)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEditFieldStatic(
                          'Nom de l\'entreprise',
                          editCompanyController,
                          Icons.business_rounded,
                        ),
                        SizedBox(height: 12.h),
                        _buildEditFieldStatic(
                          'Titre du poste',
                          editTitleController,
                          Icons.work_rounded,
                        ),
                        SizedBox(height: 12.h),
                        _buildEditFieldStatic(
                          'Localisation / Ville',
                          editLocationController,
                          Icons.location_on_rounded,
                        ),
                        SizedBox(height: 12.h),
                        _buildEditFieldStatic(
                          'Niveau d\'expérience / Diplôme requis',
                          editLevelController,
                          Icons.school_rounded,
                        ),
                        SizedBox(height: 12.h),
                        _buildEditFieldStatic(
                          'Fourchette salariale',
                          editSalaryController,
                          Icons.payments_rounded,
                        ),
                        SizedBox(height: 12.h),
                        _buildEditFieldStatic(
                          'Email de contact',
                          editEmailController,
                          Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        SizedBox(height: 12.h),
                        _buildEditFieldStatic(
                          'Numéro WhatsApp',
                          editWhatsappController,
                          Icons.chat_rounded,
                          keyboardType: TextInputType.phone,
                        ),
                        SizedBox(height: 12.h),

                        Text(
                          'Type de contrat',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        DropdownButtonFormField<String>(
                          value: contractTypes.contains(editContractType)
                              ? editContractType
                              : contractTypes.first,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 12.h,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            fillColor: const Color(0xFFF8FAFC),
                            filled: true,
                          ),
                          items: contractTypes
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null)
                              setModalState(() => editContractType = val);
                          },
                        ),
                        SizedBox(height: 16.h),

                        // ─── SECTEUR ET TAGS ───
                        Text(
                          'Secteur / Compétences clés (Tags)',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: customTagController,
                                decoration: InputDecoration(
                                  hintText:
                                      'Ajouter un tag (ex: Java, Marketing...)',
                                  hintStyle: TextStyle(
                                    fontSize: 12.sp,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14.w,
                                    vertical: 10.h,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  fillColor: const Color(0xFFF8FAFC),
                                  filled: true,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            IconButton.filled(
                              onPressed: () {
                                final text = customTagController.text.trim();
                                if (text.isNotEmpty) {
                                  setModalState(() {
                                    editSelectedTags.add(text);
                                    customTagController.clear();
                                  });
                                }
                              },
                              icon: const Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A8A),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),

                        if (editSelectedTags.isNotEmpty) ...[
                          Text(
                            'Tags sélectionnés :',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Wrap(
                            spacing: 6.w,
                            runSpacing: 6.h,
                            children: editSelectedTags.map((tag) {
                              return Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 5.h,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(14.r),
                                  border: Border.all(
                                    color: const Color(0xFF93C5FD),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      tag,
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1D4ED8),
                                      ),
                                    ),
                                    SizedBox(width: 4.w),
                                    GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          editSelectedTags.remove(tag);
                                        });
                                      },
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 14.r,
                                        color: const Color(0xFF1D4ED8),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 12.h),
                        ],

                        Text(
                          'Secteurs suggérés (Toucher pour ajouter) :',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Wrap(
                          spacing: 6.w,
                          runSpacing: 6.h,
                          children:
                              [
                                'Informatique',
                                'Marketing',
                                'Commerce',
                                'Finance',
                                'RH',
                                'Gestion de projet',
                                'Développement Mobile',
                                'Flutter',
                                'Design',
                                'Comptabilité',
                                'Vente',
                                'Logistique',
                                'BTP',
                                'Santé',
                                'Droit',
                                'Formation',
                                'Communication',
                                'E-commerce',
                                'Accueil',
                                'Hôtellerie',
                              ].map((tag) {
                                final isSelected = editSelectedTags.contains(
                                  tag,
                                );
                                return GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      if (isSelected) {
                                        editSelectedTags.remove(tag);
                                      } else {
                                        editSelectedTags.add(tag);
                                      }
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10.w,
                                      vertical: 5.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF1E3A8A)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF1E3A8A)
                                            : const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                    child: Text(
                                      tag,
                                      style: TextStyle(
                                        fontSize: 11.5.sp,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                        SizedBox(height: 16.h),

                        _buildEditFieldStatic(
                          'Description détaillée du poste',
                          editDescriptionController,
                          Icons.description_rounded,
                          maxLines: 5,
                        ),
                        SizedBox(height: 24.h),

                        ElevatedButton(
                          onPressed: editIsSaving
                              ? null
                              : () async {
                                  setModalState(() => editIsSaving = true);
                                  try {
                                    final updatedTags = editSelectedTags
                                        .toList();
                                    if (!updatedTags.contains(
                                      editContractType,
                                    )) {
                                      updatedTags.add(editContractType);
                                    }

                                    final updatedJob = await Supabase
                                        .instance
                                        .client
                                        .from('jobs')
                                        .update({
                                          'company_name': editCompanyController
                                              .text
                                              .trim(),
                                          'job_title': editTitleController.text
                                              .trim(),
                                          'location': editLocationController
                                              .text
                                              .trim(),
                                          'required_level': editLevelController
                                              .text
                                              .trim(),
                                          'salary_range': editSalaryController
                                              .text
                                              .trim(),
                                          'contact_email': editEmailController
                                              .text
                                              .trim(),
                                          'whatsapp_number':
                                              editWhatsappController.text
                                                  .trim(),
                                          'description':
                                              editDescriptionController.text
                                                  .trim(),
                                          'tags': updatedTags,
                                          'is_approved': false,
                                        })
                                        .eq('id', job['id'])
                                        .select('id, is_approved')
                                        .maybeSingle();

                                    if (updatedJob == null) {
                                      throw Exception(
                                        'Mise a jour refusee ou offre introuvable.',
                                      );
                                    }

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Offre mise à jour. Elle repasse en attente d\'approbation admin.',
                                          ),
                                          backgroundColor: Color(0xFF16A34A),
                                        ),
                                      );
                                      await onJobUpdated?.call();
                                    }
                                  } catch (e) {
                                    debugPrint('Erreur mise à jour offre: $e');
                                    setModalState(() => editIsSaving = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Erreur lors de la mise à jour de l\'offre.',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 50.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                          ),
                          child: editIsSaving
                              ? SizedBox(
                                  width: 20.r,
                                  height: 20.r,
                                  child: const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Enregistrer les modifications',
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
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

Widget _buildEditFieldStatic(
  String label,
  TextEditingController controller,
  IconData icon, {
  int maxLines = 1,
  TextInputType keyboardType = TextInputType.text,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF334155),
        ),
      ),
      SizedBox(height: 6.h),
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          prefixIcon: maxLines == 1
              ? Icon(icon, size: 18.r, color: const Color(0xFF64748B))
              : null,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14.w,
            vertical: 12.h,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
          ),
          fillColor: const Color(0xFFF8FAFC),
          filled: true,
        ),
      ),
    ],
  );
}

void _confirmDeleteJobFromProfile(
  BuildContext context,
  Map<String, dynamic> job,
) {
  final jobId = job['id'] as String;
  final jobTitle = job['job_title'] ?? 'cette offre';

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          'Supprimer l\'offre ?',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer l\'offre "$jobTitle" ? Cette action est irréversible.',
          style: TextStyle(fontSize: 14.sp, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                debugPrint('Début suppression offre depuis profil: $jobId');

                // Nettoyer les dépendances dans l'ordre inverse des contraintes
                try {
                  debugPrint('Suppression des job_reports...');
                  await Supabase.instance.client
                      .from('job_reports')
                      .delete()
                      .eq('job_id', jobId);
                } catch (e) {
                  debugPrint('Erreur suppression job_reports: $e');
                }

                try {
                  debugPrint('Suppression des applications...');
                  await Supabase.instance.client
                      .from('applications')
                      .delete()
                      .eq('job_id', jobId);
                } catch (e) {
                  debugPrint('Erreur suppression applications: $e');
                }

                try {
                  debugPrint('Suppression des swipes_log...');
                  await Supabase.instance.client
                      .from('swipes_log')
                      .delete()
                      .eq('job_id', jobId);
                } catch (e) {
                  debugPrint('Erreur suppression swipes_log: $e');
                }

                // Supprimer l'offre elle-même
                debugPrint('Suppression de l\'offre jobs...');
                final deleteResult = await Supabase.instance.client
                    .from('jobs')
                    .delete()
                    .eq('id', jobId);

                debugPrint('Résultat suppression: $deleteResult');

                // Vérifier que l'offre a bien été supprimée
                try {
                  final checkResponse = await Supabase.instance.client
                      .from('jobs')
                      .select('id')
                      .eq('id', jobId)
                      .maybeSingle();

                  if (checkResponse != null) {
                    debugPrint(
                      'ERREUR: L\'offre existe toujours après suppression!',
                    );
                    throw Exception(
                      'L\'offre n\'a pas été supprimée de la base de données',
                    );
                  }
                } catch (e) {
                  debugPrint('Erreur vérification: $e');
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Offre supprimée avec succès.'),
                      backgroundColor: Color(0xFF16A34A),
                    ),
                  );
                  Navigator.of(context).pop('deleted');
                }
              } catch (e) {
                debugPrint('Erreur suppression offre: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Erreur lors de la suppression: ${e.toString()}',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      );
    },
  );
}
