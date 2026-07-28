import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:djossimatch/core/utils/tag_normalizer.dart';
import 'package:intl/intl.dart';

import 'package:go_router/go_router.dart';
import 'package:djossimatch/features/recruiter/presentation/widgets/candidate_cv_swipe_card.dart';

class RecruiterPostJobScreen extends StatefulWidget {
  final bool embedInNavBar;

  const RecruiterPostJobScreen({super.key, this.embedInNavBar = false});

  @override
  State<RecruiterPostJobScreen> createState() => _RecruiterPostJobScreenState();
}

class _RecruiterPostJobScreenState extends State<RecruiterPostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _jobsRealtimeChannel;

  final _companyController = TextEditingController();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _levelController = TextEditingController();
  final _salaryController = TextEditingController();
  final _emailController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _coverLetterController = TextEditingController();
  final _deadlineController = TextEditingController();

  String _contractType = 'CDI';
  String _contactChannel = 'email'; // 'email' or 'whatsapp'
  bool _requiresCoverLetter = false;
  bool _isSalaryNonNegotiable = false;
  bool _isLoading = false;
  bool _isLoadingTags = true;
  List<String> _availableTags = [];
  final Set<String> _selectedTags = {};
  String _tagSearchQuery = '';
  final _tagSearchController = TextEditingController();
  bool _isSuccess = false;

  // Tab state: 0 = Post, 1 = Mes offres
  int _tabIndex = 0;
  bool _isLoadingCandidatures = false;
  List<Map<String, dynamic>> _myJobs = [];
  DateTime _lastRealtimeJobsReload = DateTime.fromMillisecondsSinceEpoch(0);

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
      debugPrint('Error initiating chat: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'initier la discussion.')),
        );
      }
    }
  }

  final List<String> _contractTypes = [
    'CDI',
    'CDD',
    'Stage',
    'Alternance',
    'Freelance',
    'Intérim',
  ];

  @override
  void initState() {
    super.initState();
    _loadAvailableTags();
    _loadCandidatures();
    _setupJobsRealtime();
  }

  void _setupJobsRealtime() {
    final recruiterId = _supabase.auth.currentUser?.id;
    if (recruiterId == null) return;

    _jobsRealtimeChannel = _supabase
        .channel('public:recruiter_jobs:$recruiterId')
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
    _loadCandidatures(forceRefresh: true);
  }

  Future<void> _loadAvailableTags() async {
    try {
      final tagsResponse = await _supabase
          .from('jobs')
          .select('tags')
          .eq('is_approved', true)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Timeout'),
          );
      final List<String> rawTags = [];
      for (var row in tagsResponse as List) {
        if (row['tags'] != null) {
          rawTags.addAll(List<String>.from(row['tags']));
        }
      }
      final uniqueTags = TagNormalizer.deduplicateTags(
        rawTags,
      ).where((t) => !TagNormalizer.isGeneric(t)).toList();
      if (mounted) {
        setState(() {
          _availableTags = uniqueTags;
          _isLoadingTags = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement tags: $e');
      if (mounted) setState(() => _isLoadingTags = false);
    }
  }

  @override
  void dispose() {
    if (_jobsRealtimeChannel != null) {
      _supabase.removeChannel(_jobsRealtimeChannel!);
    }
    _companyController.dispose();
    _titleController.dispose();
    _locationController.dispose();
    _levelController.dispose();
    _salaryController.dispose();
    _emailController.dispose();
    _whatsappController.dispose();
    _descriptionController.dispose();
    _coverLetterController.dispose();
    _deadlineController.dispose();
    _tagSearchController.dispose();
    super.dispose();
  }

  String _cleanPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length == 10) {
      return '225$cleaned';
    } else if (cleaned.length == 8) {
      return '22507$cleaned';
    }
    return cleaned;
  }

  String _getDefaultDeadline() {
    final fallbackDate = DateTime.now().add(const Duration(days: 21));
    return DateFormat('yyyy-MM-dd').format(fallbackDate);
  }

  Future<void> _submitJob() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veuillez sélectionner au moins un tag'),
          backgroundColor: Colors.red.shade400,
        ),
      );
      return;
    }

    final emailText = _contactChannel == 'email'
        ? _emailController.text.trim()
        : null;
    final rawWhatsapp = _contactChannel == 'whatsapp'
        ? _whatsappController.text.trim()
        : '';
    final whatsappText = rawWhatsapp.isNotEmpty
        ? _cleanPhone(rawWhatsapp)
        : null;

    if (_contactChannel == 'email' &&
        (emailText == null || emailText.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir votre adresse e-mail de contact'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_contactChannel == 'whatsapp' && (rawWhatsapp.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir votre numéro WhatsApp de contact'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final randomSuffix = Random().nextInt(1000000).toString().padLeft(6, '0');
    final uniqueSourceUrl =
        'recruiter_post_${DateTime.now().millisecondsSinceEpoch}_$randomSuffix';

    final tags = _selectedTags.toList();

    // Add contract type to tags for filtering if it's not already there
    if (!tags.contains(_contractType)) {
      tags.add(_contractType);
    }

    String salaryText = _salaryController.text.trim();
    if (_isSalaryNonNegotiable) {
      if (salaryText.isNotEmpty) {
        if (!salaryText.toLowerCase().contains('non négociable')) {
          salaryText += ' (Non négociable)';
        }
      } else {
        salaryText = 'Non négociable';
      }
    }

    final rawData = {
      'company_name': _companyController.text.trim(),
      'job_title': _titleController.text.trim(),
      'location': _locationController.text.trim(),
      'required_level': _levelController.text.trim(),
      'salary_range': salaryText,
      'contact_email': emailText,
      'whatsapp_number': whatsappText,
      'description': _descriptionController.text.trim(),
      'tags': tags,
      'contract_type': _contractType,
      'requires_cover_letter': _requiresCoverLetter,
      'cover_letter_instructions': null,
      'deadline': _deadlineController.text.trim().isNotEmpty
          ? _deadlineController.text.trim()
          : _getDefaultDeadline(),
    };

    final jobData = {
      'company_name': rawData['company_name'],
      'job_title': rawData['job_title'],
      'location': rawData['location'] ?? "Abidjan",
      'required_level': rawData['required_level'],
      'salary_range': rawData['salary_range'] != ""
          ? rawData['salary_range']
          : null,
      'contact_email': emailText,
      'whatsapp_number': whatsappText,
      'description': rawData['description'],
      'tags': tags,
      'requires_cover_letter': _requiresCoverLetter,
      'cover_letter_instructions': null,
      'deadline': rawData['deadline'],
      'is_ai_verified':
          false, // Scammers prevention: all recruiter jobs start unverified
      'is_approved':
          false, // Scammers prevention: recruiter jobs must be approved by admin
      'source_url': uniqueSourceUrl,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'raw_data': rawData,
      'recruiter_id': _supabase.auth.currentUser?.id,
    };

    try {
      final response = await _supabase.from('jobs').insert(jobData);
      debugPrint("Job Insertion Success: $response");
      setState(() {
        _isSuccess = true;
      });
      _loadCandidatures(forceRefresh: true);
    } catch (e) {
      debugPrint("Error inserting recruiter job: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de la publication : ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadCandidatures({bool forceRefresh = false}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoadingCandidatures = true);
    try {
      debugPrint(
        'Chargement des offres recruteur, forceRefresh: $forceRefresh',
      );

      // 1. Fetch all jobs by this recruiter
      final jobsResponse = await _supabase
          .from('jobs')
          .select('*')
          .eq('recruiter_id', userId)
          .order('created_at', ascending: false);

      final jobs = List<Map<String, dynamic>>.from(jobsResponse as List);
      debugPrint('Nombre d\'offres chargées: ${jobs.length}');

      if (jobs.isEmpty) {
        if (mounted) {
          setState(() {
            _myJobs = [];
            _isLoadingCandidatures = false;
          });
        }
        return;
      }

      // 2. Fetch all right-swipes on those jobs
      final jobIds = jobs.map((j) => j['id'] as String).toList();
      final swipesResponse = await _supabase
          .from('swipes_log')
          .select('job_id')
          .inFilter('job_id', jobIds)
          .eq('direction', 'right');

      final swipes = List<Map<String, dynamic>>.from(swipesResponse as List);
      debugPrint('Nombre de swipes chargés: ${swipes.length}');

      final Map<String, int> countByJob = {};
      for (final swipe in swipes) {
        final jobId = swipe['job_id'] as String?;
        if (jobId == null) continue;
        countByJob[jobId] = (countByJob[jobId] ?? 0) + 1;
      }

      for (final job in jobs) {
        final count = countByJob[job['id']] ?? 0;
        job['applications'] = List.generate(count, (index) => {'index': index});
      }

      if (mounted) {
        setState(() {
          _myJobs = jobs;
          _isLoadingCandidatures = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading candidatures: $e');
      if (mounted) setState(() => _isLoadingCandidatures = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Espace Recruteurs',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: !widget.embedInNavBar,
        leading: widget.embedInNavBar
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/auth');
                  }
                },
              ),
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            final isLoggedIn = _supabase.auth.currentUser != null;
            return Column(
              children: [
                // Tab bar: Poster / Candidatures (Visible uniquement si le recruteur est connecté)
                if (isLoggedIn)
                  Container(
                    margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
                    padding: EdgeInsets.all(4.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Row(
                      children: [
                        _buildTab(
                          'Poster une offre',
                          0,
                          Icons.add_circle_outline,
                        ),
                        _buildTab('Mes offres', 1, Icons.work_outline_rounded),
                      ],
                    ),
                  ),
                SizedBox(height: 8.h),
                Expanded(
                  child: (!isLoggedIn || _tabIndex == 0)
                      ? (_isSuccess ? _buildSuccessView() : _buildFormView())
                      : _buildCandidaturesView(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index, IconData icon) {
    final isSelected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _tabIndex = index);
          if (index == 1) {
            _loadCandidatures(forceRefresh: true);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10.r),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16.r,
                color: isSelected
                    ? const Color(0xFF1E3A8A)
                    : const Color(0xFF94A3B8),
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF1E3A8A)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCandidaturesView() {
    if (_isLoadingCandidatures) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
      );
    }

    if (_myJobs.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadCandidatures(forceRefresh: true),
        color: const Color(0xFF1E3A8A),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(32.r),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 40.h),
              Icon(
                Icons.work_off_rounded,
                size: 56.r,
                color: const Color(0xFFCBD5E1),
              ),
              SizedBox(height: 16.h),
              Text(
                'Aucune offre publiée',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF64748B),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Publiez votre première offre d\'emploi pour suivre les personnes intéressées.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              SizedBox(height: 24.h),
              ElevatedButton.icon(
                onPressed: () => _loadCandidatures(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Actualiser mes offres'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 12.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCandidatures,
      color: const Color(0xFF1E3A8A),
      child: ListView.builder(
        padding: EdgeInsets.all(16.r),
        itemCount: _myJobs.length,
        itemBuilder: (context, index) {
          final job = _myJobs[index];
          final appCount = (job['applications'] as List?)?.length ?? 0;
          final isApproved = job['is_approved'] == true;
          final hasWhatsapp =
              job['whatsapp_number'] != null &&
              job['whatsapp_number'].toString().trim().isNotEmpty;
          final contactChannelLabel = hasWhatsapp ? 'WhatsApp' : 'E-mail';

          return Container(
            margin: EdgeInsets.only(bottom: 16.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16.r),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job['job_title'] ?? 'Sans titre',
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              '${job['company_name'] ?? ''} • ${job['location'] ?? ''}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: const Color(0xFF64748B),
                              ),
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
                          color: isApproved
                              ? const Color(0xFFF0FDF4)
                              : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: isApproved
                                ? const Color(0xFFBBF7D0)
                                : const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6.r,
                              height: 6.r,
                              decoration: BoxDecoration(
                                color: isApproved
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFD97706),
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 5.w),
                            Text(
                              isApproved ? 'En ligne' : 'En examen',
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w600,
                                color: isApproved
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Buttons Bar: Voir / Modifier / Supprimer
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFF1F5F9)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showJobDetailsModal(job),
                          icon: Icon(
                            Icons.visibility_outlined,
                            size: 14.r,
                            color: const Color(0xFF1E3A8A),
                          ),
                          label: Text(
                            'Voir',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: const Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 6.h),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openEditJobModal(job),
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 14.r,
                            color: const Color(0xFFD97706),
                          ),
                          label: Text(
                            'Modifier',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: const Color(0xFFD97706),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 6.h),
                            side: const BorderSide(color: Color(0xFFFCD34D)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmDeleteJob(job),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 14.r,
                            color: const Color(0xFFDC2626),
                          ),
                          label: Text(
                            'Supprimer',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: const Color(0xFFDC2626),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 6.h),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 14.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 10.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Canal de réception',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 3.h),
                              Text(
                                contactChannelLabel,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 10.h,
                          ),
                          decoration: BoxDecoration(
                            color: appCount > 0
                                ? const Color(0xFFFFF7ED)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: appCount > 0
                                  ? const Color(0xFFFED7AA)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Intéressés',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 3.h),
                              Text(
                                appCount == 0
                                    ? 'Aucun swipe'
                                    : '$appCount swipe${appCount > 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: appCount > 0
                                      ? const Color(0xFFC2410C)
                                      : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCandidateRow(
    Map<String, dynamic> candidate, [
    Map<String, dynamic>? job,
  ]) {
    final name = candidate['full_name'] ?? 'Candidat';
    final rawSkills = candidate['skills'];
    final List<String> skillsList = rawSkills is List
        ? List<String>.from(rawSkills)
        : [];
    final skillsStr = skillsList.take(3).join(', ');
    final bio = candidate['biography'] ?? candidate['bio'] ?? '';
    final cvUrl = candidate['cv_url'] ?? candidate['cvUrl'];
    final sexe = candidate['sexe'] ?? candidate['gender'];
    final candidateId =
        candidate['id'] as String? ?? candidate['user_id'] as String? ?? '';

    final hasEmail =
        job != null &&
        job['contact_email'] != null &&
        job['contact_email'].toString().trim().isNotEmpty;
    final hasWhatsapp =
        job != null &&
        job['whatsapp_number'] != null &&
        job['whatsapp_number'].toString().trim().isNotEmpty;

    final initials = name
        .split(' ')
        .map((s) => s.isNotEmpty ? s[0] : '')
        .take(2)
        .join()
        .toUpperCase();
    final swipedAt = candidate['swiped_at'] != null
        ? DateTime.tryParse(candidate['swiped_at'])
        : null;
    final timeAgo = swipedAt != null ? _formatTimeAgo(swipedAt) : '';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20.r,
                backgroundColor: const Color(0xFF1E3A8A),
                child: Text(
                  initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (skillsStr.isNotEmpty)
                      Text(
                        skillsStr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    SizedBox(height: 3.h),
                    // Channel indicator badge
                    if (hasEmail)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: const Color(0xFF93C5FD)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.email_outlined,
                              size: 12.r,
                              color: const Color(0xFF1D4ED8),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'Candidature transmise par E-mail',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1D4ED8),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (hasWhatsapp)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_outlined,
                              size: 12.r,
                              color: const Color(0xFF15803D),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'Candidature transmise par WhatsApp',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF5FF),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: const Color(0xFFC084FC)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.smartphone_rounded,
                              size: 12.r,
                              color: const Color(0xFF9333EA),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'Candidature 100% In-App — Fiche & Tchat',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF9333EA),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (timeAgo.isNotEmpty)
                Text(
                  timeAgo,
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FullScreenCvViewer(
                          candidateId: candidateId.isNotEmpty
                              ? candidateId
                              : null,
                          candidateName: name,
                          skills: skillsList,
                          biography: bio,
                          sexe: sexe,
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.description_outlined, size: 14.r),
                  label: Text(
                    'Voir CV',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF97316),
                    side: const BorderSide(color: Color(0xFFF97316)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (candidateId.isNotEmpty) {
                      _initiateChatAndNavigate(context, candidateId, name);
                    }
                  },
                  icon: Icon(Icons.chat_rounded, size: 14.r),
                  label: Text(
                    'Discuter',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().toUtc().difference(date);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return '${date.day}/${date.month}';
  }

  Widget _buildSuccessView() {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 50),
            ),
            SizedBox(height: 24.h),
            Text(
              'Offre soumise avec succès !',
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    color: const Color(0xFFF97316),
                    size: 24.r,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Votre offre est en attente de vérification par notre équipe.\n\nElle sera publiée et visible par les candidats après validation (sous 24h maximum).',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: const Color(0xFF92400E),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 40.h),
            SizedBox(
              width: double.infinity,
              height: 56.h,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isSuccess = false;
                    _companyController.clear();
                    _titleController.clear();
                    _locationController.clear();
                    _levelController.clear();
                    _salaryController.clear();
                    _emailController.clear();
                    _whatsappController.clear();
                    _descriptionController.clear();
                    _coverLetterController.clear();
                    _deadlineController.clear();
                    _selectedTags.clear();
                    _contractType = 'CDI';
                    _contactChannel = 'email';
                    _requiresCoverLetter = false;
                    _isSalaryNonNegotiable = false;
                  });

                  if (!widget.embedInNavBar) {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go('/recruiter-swipe');
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      color: Colors.white,
                      size: 20.r,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Ajouter d\'autres offres',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Safety reminder
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFD97706),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rappel Anti-Fraude important',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Tous les recrutements sur Djorssi Match sont gratuits pour les candidats. Les demandes de frais de dossier, de formation payante ou d\'argent pour passer un entretien sont strictement interdites. Tout compte suspect sera banni.',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: const Color(0xFFB45309),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),

            // Form inputs
            Text(
              'Informations de l\'entreprise',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 12.h),

            _buildTextField(
              controller: _companyController,
              label: 'Nom de l\'entreprise',
              hint: 'Ex: Orange CI, Boutique Ivoire...',
              icon: Icons.business,
              validator: (v) =>
                  v!.isEmpty ? 'Veuillez entrer le nom de l\'entreprise' : null,
            ),
            SizedBox(height: 16.h),

            Text(
              'Détails du poste',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 12.h),

            _buildTextField(
              controller: _titleController,
              label: 'Titre du poste',
              hint: 'Ex: Comptable, Chauffeur, Développeur...',
              icon: Icons.work_outline,
              validator: (v) =>
                  v!.isEmpty ? 'Veuillez entrer le titre du poste' : null,
            ),
            SizedBox(height: 16.h),

            // Contract Type Dropdown
            DropdownButtonFormField<String>(
              value: _contractType,
              decoration: InputDecoration(
                labelText: 'Type de contrat',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(
                  Icons.description_outlined,
                  color: Color(0xFF94A3B8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  borderSide: const BorderSide(
                    color: Color(0xFFF97316),
                    width: 2,
                  ),
                ),
              ),
              items: _contractTypes.map((type) {
                return DropdownMenuItem<String>(value: type, child: Text(type));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _contractType = val);
                }
              },
            ),
            SizedBox(height: 16.h),

            _buildTextField(
              controller: _locationController,
              label: 'Ville / Localisation',
              hint: 'Ex: Abidjan - Cocody, Bouaké...',
              icon: Icons.location_on_outlined,
              validator: (v) =>
                  v!.isEmpty ? 'Veuillez entrer le lieu du poste' : null,
            ),
            SizedBox(height: 16.h),

            _buildTextField(
              controller: _levelController,
              label: 'Niveau d\'études requis',
              hint: 'Ex: BAC, BAC+2, CAP, Sans diplôme...',
              icon: Icons.school_outlined,
              validator: (v) =>
                  v!.isEmpty ? 'Veuillez entrer le niveau requis' : null,
            ),
            SizedBox(height: 16.h),

            _buildTextField(
              controller: _salaryController,
              label: 'Rémunération mensuelle (Optionnel)',
              hint: _isSalaryNonNegotiable
                  ? 'Ex: 150 000 FCFA (Non négociable)'
                  : 'Ex: 150 000 FCFA, À négocier...',
              icon: Icons.payments_outlined,
            ),
            SizedBox(height: 6.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.do_not_disturb_on_outlined,
                        color: const Color(0xFF1E3A8A),
                        size: 18.r,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Salaire non négociable',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isSalaryNonNegotiable,
                    onChanged: (val) =>
                        setState(() => _isSalaryNonNegotiable = val),
                    activeThumbColor: const Color(0xFF1E3A8A),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            _buildTextField(
              controller: _deadlineController,
              label: 'Date limite (Optionnel, 21 jours par défaut)',
              hint: 'Format: JJ/MM/AAAA ou laissé vide pour +21 jours',
              icon: Icons.calendar_today_outlined,
            ),
            SizedBox(height: 16.h),

            _buildTextField(
              controller: _descriptionController,
              label: 'Description du poste & prérequis',
              hint: 'Décrivez les tâches et profil recherché...',
              icon: Icons.info_outline,
              maxLines: 4,
              validator: (v) =>
                  v!.isEmpty ? 'Veuillez entrer une description' : null,
            ),
            SizedBox(height: 16.h),

            // Tags selector from database
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.label_outline,
                        color: const Color(0xFF94A3B8),
                        size: 20.r,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Secteurs / Compétences *',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Recherchez et sélectionnez les tags qui correspondent à l\'offre',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  if (_selectedTags.isNotEmpty) ...[
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      children: _selectedTags.map((tag) {
                        return Chip(
                          label: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: const Color(0xFFF97316),
                          deleteIcon: Icon(
                            Icons.close,
                            size: 16.r,
                            color: Colors.white,
                          ),
                          onDeleted: () =>
                              setState(() => _selectedTags.remove(tag)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 12.h),
                    const Divider(),
                    SizedBox(height: 8.h),
                  ],
                  // Search field for tags
                  TextField(
                    controller: _tagSearchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un tag...',
                      hintStyle: TextStyle(
                        fontSize: 13.sp,
                        color: const Color(0xFF94A3B8),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20.r,
                        color: const Color(0xFF94A3B8),
                      ),
                      suffixIcon: _tagSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                size: 18.r,
                                color: const Color(0xFF94A3B8),
                              ),
                              onPressed: () => setState(() {
                                _tagSearchController.clear();
                                _tagSearchQuery = '';
                              }),
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 10.h,
                      ),
                    ),
                    onChanged: (val) =>
                        setState(() => _tagSearchQuery = val.toLowerCase()),
                  ),
                  SizedBox(height: 12.h),
                  if (_isLoadingTags)
                    const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_availableTags.isEmpty)
                    Text(
                      'Aucun tag disponible',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: const Color(0xFF94A3B8),
                      ),
                    )
                  else
                    Builder(
                      builder: (context) {
                        final filteredTags = _tagSearchQuery.isEmpty
                            ? _availableTags
                            : _availableTags
                                  .where(
                                    (t) => t.toLowerCase().contains(
                                      _tagSearchQuery,
                                    ),
                                  )
                                  .toList();
                        if (filteredTags.isEmpty) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            child: Text(
                              'Aucun tag trouvé pour "$_tagSearchQuery"',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          );
                        }
                        return SizedBox(
                          height: 200.h,
                          child: SingleChildScrollView(
                            child: Wrap(
                              spacing: 6.w,
                              runSpacing: 6.h,
                              children: filteredTags.map((tag) {
                                final isSelected = _selectedTags.contains(tag);
                                return FilterChip(
                                  label: Text(
                                    tag,
                                    style: TextStyle(fontSize: 12.sp),
                                  ),
                                  selected: isSelected,
                                  onSelected: (_) => setState(() {
                                    isSelected
                                        ? _selectedTags.remove(tag)
                                        : _selectedTags.add(tag);
                                  }),
                                  selectedColor: const Color(
                                    0xFFF97316,
                                  ).withValues(alpha: 0.15),
                                  checkmarkColor: const Color(0xFFF97316),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20.r),
                                    side: BorderSide(
                                      color: isSelected
                                          ? const Color(0xFFF97316)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            SizedBox(height: 24.h),

            Text(
              'Moyens de contact',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Choisissez le canal pour recevoir vos candidatures (Activez l\'un ou l\'autre)',
              style: TextStyle(fontSize: 12.sp, color: const Color(0xFF64748B)),
            ),
            SizedBox(height: 14.h),

            // ─── CANAL 1 : E-MAIL ───
            _buildTextField(
              controller: _emailController,
              label: 'Adresse e-mail de contact',
              hint: 'Ex: recrutement@entreprise.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              enabled: _contactChannel == 'email',
              validator: (v) {
                if (_contactChannel == 'email') {
                  if (v == null || v.trim().isEmpty) {
                    return 'Veuillez saisir votre adresse e-mail';
                  }
                  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  if (!emailRegex.hasMatch(v.trim())) {
                    return 'Adresse e-mail invalide';
                  }
                }
                return null;
              },
            ),
            SizedBox(height: 6.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: _contactChannel == 'email'
                    ? const Color(0xFFEFF6FF)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: _contactChannel == 'email'
                      ? const Color(0xFF93C5FD)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.email_rounded,
                        size: 18.r,
                        color: _contactChannel == 'email'
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF94A3B8),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Recevoir par E-mail',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: _contactChannel == 'email'
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _contactChannel == 'email',
                    activeColor: const Color(0xFF1D4ED8),
                    onChanged: (val) {
                      if (val) {
                        setState(() => _contactChannel = 'email');
                      }
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 18.h),

            // ─── CANAL 2 : WHATSAPP ───
            _buildTextField(
              controller: _whatsappController,
              label: 'Numéro WhatsApp de contact',
              hint: 'Ex: 07070707',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              enabled: _contactChannel == 'whatsapp',
              validator: (v) {
                if (_contactChannel == 'whatsapp') {
                  if (v == null || v.trim().isEmpty) {
                    return 'Veuillez saisir votre numéro WhatsApp';
                  }
                }
                return null;
              },
            ),
            SizedBox(height: 6.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: _contactChannel == 'whatsapp'
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: _contactChannel == 'whatsapp'
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.chat_rounded,
                        size: 18.r,
                        color: _contactChannel == 'whatsapp'
                            ? const Color(0xFF15803D)
                            : const Color(0xFF94A3B8),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Recevoir par WhatsApp',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: _contactChannel == 'whatsapp'
                              ? const Color(0xFF15803D)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _contactChannel == 'whatsapp',
                    activeColor: const Color(0xFF16A34A),
                    onChanged: (val) {
                      if (val) {
                        setState(() => _contactChannel = 'whatsapp');
                      }
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 18.h),

            // Motivation Letter Switch
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: SwitchListTile(
                title: Text(
                  'Exiger une lettre de motivation',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                subtitle: Text(
                  'Le candidat devra rédiger une lettre lors du swipe.',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: const Color(0xFF64748B),
                  ),
                ),
                value: _requiresCoverLetter,
                activeColor: const Color(0xFFF97316),
                onChanged: (val) {
                  setState(() => _requiresCoverLetter = val);
                },
              ),
            ),
            SizedBox(height: 32.h),

            // Fraud warning with legal consequences
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.gavel_rounded,
                    color: const Color(0xFFDC2626),
                    size: 24.r,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚠️ Avertissement légal',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF991B1B),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'Toute publication d\'offre d\'emploi frauduleuse, trompeuse ou à caractère d\'arnaque est passible de poursuites judiciaires conformément à la loi ivoirienne.\n\nVotre identité est enregistrée. En cas de signalement, les informations seront transmises aux autorités compétentes.',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: const Color(0xFFB91C1C),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),

            // Submit Button
            SizedBox(
              height: 56.h,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitJob,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20.h,
                        width: 20.h,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Soumettre pour vérification',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: enabled ? const Color(0xFF94A3B8) : const Color(0xFFCBD5E1),
        ),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
        prefixIcon: Icon(
          icon,
          color: enabled ? const Color(0xFF94A3B8) : const Color(0xFFE2E8F0),
        ),
        filled: !enabled,
        fillColor: enabled ? null : const Color(0xFFF1F5F9),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: Color(0xFFF97316), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }

  void _showJobDetailsModal(Map<String, dynamic> job) {
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
                          _buildDetailBadge(
                            Icons.assignment_ind_outlined,
                            contract,
                            const Color(0xFFEFF6FF),
                            const Color(0xFF1D4ED8),
                          ),
                          _buildDetailBadge(
                            Icons.payments_outlined,
                            salary,
                            const Color(0xFFF0FDF4),
                            const Color(0xFF15803D),
                          ),
                          _buildDetailBadge(
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

  Widget _buildDetailBadge(IconData icon, String label, Color bg, Color text) {
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

  void _openEditJobModal(Map<String, dynamic> job) {
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
                          _buildEditField(
                            'Nom de l\'entreprise',
                            editCompanyController,
                            Icons.business_rounded,
                          ),
                          SizedBox(height: 12.h),
                          _buildEditField(
                            'Titre du poste',
                            editTitleController,
                            Icons.work_rounded,
                          ),
                          SizedBox(height: 12.h),
                          _buildEditField(
                            'Localisation / Ville',
                            editLocationController,
                            Icons.location_on_rounded,
                          ),
                          SizedBox(height: 12.h),
                          _buildEditField(
                            'Niveau d\'expérience / Diplôme requis',
                            editLevelController,
                            Icons.school_rounded,
                          ),
                          SizedBox(height: 12.h),
                          _buildEditField(
                            'Fourchette salariale',
                            editSalaryController,
                            Icons.payments_rounded,
                          ),
                          SizedBox(height: 12.h),
                          _buildEditField(
                            'Email de contact',
                            editEmailController,
                            Icons.email_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          SizedBox(height: 12.h),
                          _buildEditField(
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
                            value: _contractTypes.contains(editContractType)
                                ? editContractType
                                : _contractTypes.first,
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
                            items: _contractTypes
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
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10.w,
                                        vertical: 5.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF1E3A8A)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
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

                          _buildEditField(
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
                                      final contactEmail = editEmailController
                                          .text
                                          .trim();
                                      final whatsappNumber =
                                          editWhatsappController.text.trim();
                                      if (contactEmail.isEmpty &&
                                          whatsappNumber.isEmpty) {
                                        throw Exception(
                                          'Ajoutez au moins un contact: email ou WhatsApp.',
                                        );
                                      }

                                      final updatedTags = editSelectedTags
                                          .toList();
                                      if (!updatedTags.contains(
                                        editContractType,
                                      )) {
                                        updatedTags.add(editContractType);
                                      }

                                      final updatedJob = await _supabase
                                          .from('jobs')
                                          .update({
                                            'company_name':
                                                editCompanyController.text
                                                    .trim(),
                                            'job_title': editTitleController
                                                .text
                                                .trim(),
                                            'location': editLocationController
                                                .text
                                                .trim(),
                                            'required_level':
                                                editLevelController.text.trim(),
                                            'salary_range': editSalaryController
                                                .text
                                                .trim(),
                                            'contact_email': contactEmail,
                                            'whatsapp_number': whatsappNumber,
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

                                      if (mounted) {
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
                                        _loadCandidatures();
                                      }
                                    } catch (e) {
                                      debugPrint(
                                        'Erreur mise à jour offre: $e',
                                      );
                                      setModalState(() => editIsSaving = false);
                                      if (mounted) {
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

  Widget _buildEditField(
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
              borderSide: const BorderSide(
                color: Color(0xFF2563EB),
                width: 1.5,
              ),
            ),
            fillColor: const Color(0xFFF8FAFC),
            filled: true,
          ),
        ),
      ],
    );
  }

  void _confirmDeleteJob(Map<String, dynamic> job) {
    final jobId = job['id'] as String;
    final jobTitle = job['job_title'] ?? 'cette offre';

    showDialog(
      context: context,
      builder: (context) {
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  debugPrint('Début suppression offre: $jobId');

                  // Nettoyer les dépendances dans l'ordre inverse des contraintes
                  try {
                    debugPrint('Suppression des job_reports...');
                    await _supabase
                        .from('job_reports')
                        .delete()
                        .eq('job_id', jobId);
                  } catch (e) {
                    debugPrint('Erreur suppression job_reports: $e');
                  }

                  try {
                    debugPrint('Suppression des applications...');
                    await _supabase
                        .from('applications')
                        .delete()
                        .eq('job_id', jobId);
                  } catch (e) {
                    debugPrint('Erreur suppression applications: $e');
                  }

                  try {
                    debugPrint('Suppression des swipes_log...');
                    await _supabase
                        .from('swipes_log')
                        .delete()
                        .eq('job_id', jobId);
                  } catch (e) {
                    debugPrint('Erreur suppression swipes_log: $e');
                  }

                  // Supprimer l'offre elle-même
                  debugPrint('Suppression de l\'offre jobs...');
                  final deleteResult = await _supabase
                      .from('jobs')
                      .delete()
                      .eq('id', jobId);

                  debugPrint('Résultat suppression: $deleteResult');

                  // Vérifier que l'offre a bien été supprimée
                  try {
                    final checkResponse = await _supabase
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

                  if (mounted) {
                    // Mettre à jour l'interface immédiatement
                    setState(() {
                      _myJobs.removeWhere((j) => j['id'] == jobId);
                    });

                    // Recharger pour synchroniser avec la base
                    await _loadCandidatures();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Offre supprimée avec succès.'),
                        backgroundColor: Color(0xFF16A34A),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Erreur suppression offre: $e');
                  if (mounted) {
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
}
