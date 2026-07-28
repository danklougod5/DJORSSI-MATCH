import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widgets/candidate_cv_swipe_card.dart';
import '../../../core/cache/local_cache.dart';
import 'package:go_router/go_router.dart';

import 'package:djossimatch/core/utils/tag_normalizer.dart';

class RecruiterSwipeScreen extends StatefulWidget {
  final bool embedInNavBar;

  const RecruiterSwipeScreen({
    super.key,
    this.embedInNavBar = false,
  });

  @override
  State<RecruiterSwipeScreen> createState() => _RecruiterSwipeScreenState();
}

class _RecruiterSwipeScreenState extends State<RecruiterSwipeScreen> {
  final _supabase = Supabase.instance.client;
  final CardSwiperController _controller = CardSwiperController();
  
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _candidates = [];
  final int _swiperKey = 0;
  CardSwiperDirection _dragDirection = CardSwiperDirection.none;
  int _currentIndex = 0;
  String? _recruiterSector;
  bool _showFilterBar = false;

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

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  Future<void> _loadCandidates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      String? recruiterIndustry;
      String recruiterIndustryLower = '';
      List<String> swipedIds = [];

      if (user != null) {
        // 1. Fetch recruiter's own industry sector & block status
        final recruiterProfile = await _supabase
            .from('profiles')
            .select('company_industry, is_blocked')
            .eq('id', user.id)
            .maybeSingle();

        if (recruiterProfile != null && recruiterProfile['is_blocked'] == true) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Votre compte d\'entreprise a été suspendu par l\'administration.';
            });
          }
          return;
        }

        recruiterIndustry = recruiterProfile?['company_industry'] as String?;
        recruiterIndustryLower = recruiterIndustry?.toLowerCase().trim() ?? '';
        
        if (mounted) {
          setState(() {
            _recruiterSector = _sectors.contains(recruiterIndustry) ? recruiterIndustry : null;
          });
        }

        // 2. Fetch already swiped candidate IDs from recruiter_swipes
        final swipedResponse = await _supabase
            .from('recruiter_swipes')
            .select('candidate_id')
            .eq('recruiter_id', user.id);

        swipedIds = (swipedResponse as List)
            .map((row) => row['candidate_id'] as String)
            .toList();
      }

      // 3. Fetch profiles visible to recruiters
      var query = _supabase
          .from('profiles')
          .select('id, full_name, skills, cv_url, biography, sexe, phone_number')
          .eq('is_visible_to_recruiters', true);

      // Filter by industry/skills overlap directly in the database
      if (recruiterIndustryLower.isNotEmpty &&
          recruiterIndustryLower != 'polyvalent / tout sector' &&
          recruiterIndustryLower != 'polyvalent / tout secteur' &&
          recruiterIndustryLower != 'polyvalent' &&
          recruiterIndustryLower != 'tout secteur') {
        
        final expandedKeywords = TagNormalizer.getExpandedKeywords(recruiterIndustryLower);
        final List<String> queryKeywords = [];
        for (final kw in expandedKeywords) {
          queryKeywords.add(kw);
          // Also add capitalized/display version to handle case-sensitive array matching
          queryKeywords.add(TagNormalizer.normalizeDisplay(kw));
        }
        
        final pgArray = '{${queryKeywords.map((k) => '"${k.replaceAll('"', '\\"')}"').join(',')}}';
        debugPrint('*** DEBUG: Database filtering on skills overlap with: $pgArray ***');
        query = query.filter('skills', 'ov', pgArray);
      }

      if (swipedIds.isNotEmpty) {
        query = query.not('id', 'in', '(${swipedIds.join(",")})');
      }

      final response = await query.order('created_at', ascending: false);
      final rawCandidates = List<Map<String, dynamic>>.from(response as List);
      debugPrint('*** DEBUG: Raw candidates fetched from Supabase: ${rawCandidates.length} ***');

      // Batch fetch user_cvs for all candidates in chunks of 50
      if (rawCandidates.isNotEmpty) {
        final candidateIds = rawCandidates.map((c) => c['id'] as String).toList();
        final Map<String, List<Map<String, dynamic>>> cvsByUser = {};

        for (var i = 0; i < candidateIds.length; i += 50) {
          final chunk = candidateIds.sublist(
            i,
            i + 50 > candidateIds.length ? candidateIds.length : i + 50,
          );
          try {
            final cvsResponse = await _supabase
                .from('user_cvs')
                .select('user_id, cv_data')
                .inFilter('user_id', chunk);
            final cvsList = List<Map<String, dynamic>>.from(cvsResponse as List);
            for (final cvRow in cvsList) {
              final userId = cvRow['user_id'] as String?;
              if (userId != null) {
                cvsByUser.putIfAbsent(userId, () => []).add(cvRow);
              }
            }
          } catch (cvError) {
            debugPrint('*** DEBUG: Could not batch fetch user_cvs chunk: $cvError ***');
          }
        }

        for (final candidate in rawCandidates) {
          final id = candidate['id'] as String?;
          if (id != null && cvsByUser.containsKey(id)) {
            candidate['user_cvs'] = cvsByUser[id];
          }
        }
      }

      // 4. Double check client-side filtering for safety
      final List<Map<String, dynamic>> filteredCandidates = [];
      for (final candidate in rawCandidates) {
        final candidateSkills = List<String>.from(candidate['skills'] ?? []);

        // If recruiter has no sector selected, or selected Polyvalent, show all candidates
        if (recruiterIndustryLower.isEmpty ||
            recruiterIndustryLower == 'polyvalent / tout sector' ||
            recruiterIndustryLower == 'polyvalent / tout secteur' ||
            recruiterIndustryLower == 'polyvalent' ||
            recruiterIndustryLower == 'tout secteur') {
          filteredCandidates.add(candidate);
          continue;
        }

        // Keep candidate if at least one skill/sector belongs to the recruiter's sector family
        bool isMatch = false;
        for (final skill in candidateSkills) {
          final skillLower = skill.toLowerCase().trim();
          final sameFam = TagNormalizer.sameFamily(skill, recruiterIndustryLower);
          final exactMatch = skillLower == recruiterIndustryLower;
          
          if (sameFam || exactMatch) {
            isMatch = true;
            break;
          }
        }

        if (isMatch) {
          filteredCandidates.add(candidate);
        }
      }

      // Sort to put candidate 'dody' (ID: c10d1df8-be2d-42b4-bf88-e95293bd7027) on top of the pile for testing
      filteredCandidates.sort((a, b) {
        if (a['id'] == 'c10d1df8-be2d-42b4-bf88-e95293bd7027') return -1;
        if (b['id'] == 'c10d1df8-be2d-42b4-bf88-e95293bd7027') return 1;
        return 0;
      });

      debugPrint('*** DEBUG: Candidates after filtering: ${filteredCandidates.length} ***');

      if (mounted) {
        setState(() {
          _candidates = filteredCandidates;
          _isLoading = false;
          _currentIndex = 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading candidates: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Impossible de charger les candidats. Veuillez réessayer.';
          _isLoading = false;
        });
      }
    }
  }

  void _showSectorSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 24.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                'Filtrer par secteur',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 16.h),
              SizedBox(
                height: 350.h,
                child: ListView.builder(
                  itemCount: _sectors.length,
                  itemBuilder: (context, index) {
                    final sector = _sectors[index];
                    final isSelected = _recruiterSector == sector;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        sector,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF334155),
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle_rounded, color: const Color(0xFF1E3A8A), size: 20.r)
                          : null,
                      onTap: () async {
                        Navigator.pop(ctx);
                        setState(() {
                          _isLoading = true;
                        });
                        try {
                          final user = _supabase.auth.currentUser;
                          if (user != null) {
                            await _supabase.from('profiles').update({
                              'company_industry': sector,
                            }).eq('id', user.id);
                            
                            _loadCandidates(); // Auto reload candidates!
                          }
                        } catch (e) {
                          debugPrint('Error updating swipe sector: $e');
                          setState(() {
                            _isLoading = false;
                          });
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleUndo() async {
    if (_currentIndex > 0) {
      _controller.undo();
      setState(() {
        _currentIndex--;
      });
      try {
        final user = _supabase.auth.currentUser;
        final candidate = _candidates[_currentIndex];
        if (user != null) {
          await _supabase
              .from('recruiter_swipes')
              .delete()
              .eq('recruiter_id', user.id)
              .eq('candidate_id', candidate['id']);
        }
      } catch (e) {
        debugPrint('Error deleting swipe from database on undo: $e');
      }
    }
  }

  Future<void> _handleSwipe(Map<String, dynamic> candidate, String action) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('recruiter_swipes').upsert({
        'recruiter_id': user.id,
        'candidate_id': candidate['id'],
        'action': action,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'recruiter_id,candidate_id');

      if (action == 'like') {
        _showContactSheet(candidate);
      }
    } catch (e) {
      debugPrint('Error saving recruiter swipe: $e');
    }
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

  Future<void> _initiateChatAndNavigate(
    BuildContext context,
    String candidateId,
    String candidateName,
  ) async {
    try {
      final recruiterId = _supabase.auth.currentUser?.id;
      if (recruiterId == null) {
        context.push('/recruiter-auth');
        return;
      }

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

  void _showContactSheet(Map<String, dynamic> candidate) {
    final fullName = candidate['full_name'] ?? 'Candidat';
    final candidateId = candidate['id'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Container(
          padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 36.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull indicator
              Container(
                width: 40.w,
                height: 5.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              SizedBox(height: 24.h),

              // Title
              Text(
                'Profil Sélectionné ! 🎉',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'Vous avez aimé le profil de $fullName. Souhaitez-vous lui envoyer un message ?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              SizedBox(height: 28.h),

              // Send Message Button
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(modalContext);
                  if (candidateId != null) {
                    await _initiateChatAndNavigate(context, candidateId, fullName);
                  }
                },
                icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
                label: Text('Envoyer un message à $fullName'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 54.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  textStyle: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // Continue Swiping Button
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(modalContext),
                icon: const Icon(Icons.style_outlined, color: Color(0xFF64748B)),
                label: const Text('Continuer la recherche'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  minimumSize: Size(double.infinity, 50.h),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  textStyle: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _signOut(BuildContext context) async {
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
      if (context.mounted) {
        context.go('/auth');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Chercheur de Têtes',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.tune_rounded,
            color: _showFilterBar ? const Color(0xFF1E3A8A) : const Color(0xFF0F172A),
          ),
          onPressed: () {
            setState(() {
              _showFilterBar = !_showFilterBar;
            });
            if (_showFilterBar) {
              _showSectorSelectionSheet();
            }
          },
          tooltip: 'Filtrer par secteur',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF0F172A)),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF97316)),
            )
          : Column(
              children: [
                // Toggleable Sector Filter Chip Bar (Appears when tune button is pressed)
                if (_showFilterBar)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                    color: Colors.white,
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 18.r, color: const Color(0xFF64748B)),
                        SizedBox(width: 8.w),
                        Text(
                          'Recherche :',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: GestureDetector(
                            onTap: _showSectorSelectionSheet,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(color: const Color(0xFF1E3A8A).withValues(alpha: 0.15)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _recruiterSector ?? 'Tous les secteurs',
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1E3A8A),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(Icons.arrow_drop_down_rounded, color: const Color(0xFF1E3A8A), size: 20.r),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Swipe Area
                Expanded(
                  child: _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.r),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 16.sp),
                                ),
                                SizedBox(height: 16.h),
                                ElevatedButton(
                                  onPressed: _loadCandidates,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF97316),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Réessayer'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _candidates.isEmpty
                          ? _buildEmptyState()
                          : Stack(
                              children: [
                                if (_currentIndex >= _candidates.length)
                                  _buildEmptyState(),
                                Column(
                                  children: [
                                    SizedBox(height: 4.h),
                                    Expanded(
                                      child: Center(
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth: 600.w,
                                          ),
                                          child: CardSwiper(
                                            key: ValueKey(_swiperKey),
                                            controller: _controller,
                                            cardsCount: _candidates.length,
                                            onSwipe: (prevIndex, currIndex, direction) {
                                              final candidate = _candidates[prevIndex];
                                              final action = direction == CardSwiperDirection.right ? 'like' : 'dislike';
                                              _handleSwipe(candidate, action);
                                              
                                              setState(() {
                                                _currentIndex = currIndex ?? 0;
                                                _dragDirection = CardSwiperDirection.none;
                                              });
                                              return true;
                                            },
                                            onSwipeDirectionChange: (horizontal, vertical) {
                                              setState(() {
                                                _dragDirection = horizontal;
                                              });
                                            },
                                            numberOfCardsDisplayed: (_candidates.length - _currentIndex) <= 0
                                                ? 1
                                                : ((_candidates.length - _currentIndex) >= 3 ? 3 : (_candidates.length - _currentIndex)),
                                            backCardOffset: const Offset(0, 16),
                                            duration: const Duration(milliseconds: 250),
                                            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.h),
                                            scale: 0.92,
                                            maxAngle: 25,
                                            threshold: 40,
                                            isLoop: false,
                                            onEnd: () {
                                              setState(() {
                                                _currentIndex = _candidates.length;
                                                _dragDirection = CardSwiperDirection.none;
                                              });
                                            },
                                            cardBuilder: (context, index, horizontalPercent, verticalPercent) {
                                              final candidate = _candidates[index];
                                              List<Map<String, dynamic>> experiences = [];
                                              List<Map<String, dynamic>> educations = [];
                                              String? bio = candidate['biography'];

                                              if (candidate['user_cvs'] != null && (candidate['user_cvs'] as List).isNotEmpty) {
                                                final userCvs = candidate['user_cvs'] as List;
                                                if (userCvs.isNotEmpty) {
                                                  final firstCv = userCvs.first;
                                                  final cvData = firstCv['cv_data'];
                                                  if (cvData is Map) {
                                                    if ((bio == null || bio.isEmpty) && cvData['summary'] != null && (cvData['summary'] as String).isNotEmpty) {
                                                      bio = cvData['summary'];
                                                    }
                                                    if (cvData['experiences'] is List) {
                                                      experiences = (cvData['experiences'] as List)
                                                          .map((e) => Map<String, dynamic>.from(e as Map))
                                                          .toList();
                                                    }
                                                    if (cvData['educations'] is List) {
                                                      educations = (cvData['educations'] as List)
                                                          .map((e) => Map<String, dynamic>.from(e as Map))
                                                          .toList();
                                                    }
                                                  }
                                                }
                                              }

                                              return CandidateCvSwipeCard(
                                                key: ValueKey('${candidate['id']}_${candidate['cv_url']}'),
                                                candidateId: candidate['id'] as String?,
                                                fullName: candidate['full_name'] ?? 'Candidat',
                                                skills: List<String>.from(candidate['skills'] ?? []),
                                                biography: bio,
                                                cvUrl: candidate['cv_url'],
                                                sexe: candidate['sexe'],
                                                experiences: experiences,
                                                educations: educations,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    // Bottom Deck Action Buttons — Tinder style (3 buttons: Dislike, Undo, Like)
                                    Padding(
                                      padding: EdgeInsets.only(top: 8.h, bottom: 16.h),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          // Dislike button (large)
                                          _buildActionButton(
                                            icon: Icons.close_rounded,
                                            color: const Color(0xFFEF4444),
                                            isHighlighted: _dragDirection == CardSwiperDirection.left,
                                            onTap: () {
                                              if (_currentIndex < _candidates.length) {
                                                _controller.swipe(CardSwiperDirection.left);
                                              }
                                            },
                                          ),
                                          SizedBox(width: 28.w),

                                          // Undo/Rewind button (small, in the middle)
                                          _buildActionButton(
                                            icon: Icons.replay_rounded,
                                            color: _currentIndex > 0 ? const Color(0xFFF59E0B) : Colors.grey.shade400,
                                            isHighlighted: false,
                                            isMini: true,
                                            onTap: _handleUndo,
                                          ),
                                          SizedBox(width: 28.w),
                                          
                                          // Like button (large)
                                          _buildActionButton(
                                            icon: Icons.favorite_rounded,
                                            color: const Color(0xFF22C55E),
                                            isHighlighted: _dragDirection == CardSwiperDirection.right,
                                            onTap: () {
                                              if (_currentIndex < _candidates.length) {
                                                _controller.swipe(CardSwiperDirection.right);
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline_rounded,
              color: const Color(0xFF94A3B8),
              size: 72.r,
            ),
            SizedBox(height: 16.h),
            Text(
              'Aucun candidat visible pour le moment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Revenez plus tard ou invitez des candidats à s\'inscrire !',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required bool isHighlighted,
    required VoidCallback onTap,
    bool isMini = false,
  }) {
    final size = isMini ? 52.r : 64.r;
    final iconSize = isMini ? 24.r : 28.r;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isHighlighted ? color : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: isHighlighted ? Colors.transparent : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: isHighlighted ? Colors.white : color,
          size: iconSize,
        ),
      ),
    );
  }
}
