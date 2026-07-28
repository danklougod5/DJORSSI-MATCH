import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'widgets/candidate_cv_swipe_card.dart';

class RecruiterPreviewScreen extends StatefulWidget {
  const RecruiterPreviewScreen({super.key});

  @override
  State<RecruiterPreviewScreen> createState() => _RecruiterPreviewScreenState();
}

class _RecruiterPreviewScreenState extends State<RecruiterPreviewScreen> {
  final _supabase = Supabase.instance.client;
  final CardSwiperController _controller = CardSwiperController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _candidates = [];
  int _swiperKey = 0;
  int _selectedIndex = 0;
  CardSwiperDirection _dragDirection = CardSwiperDirection.none;
  @override
  void initState() {
    super.initState();
    _loadTeaserCandidates();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadTeaserCandidates() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, skills, cv_url, biography, sexe, phone_number')
          .eq('is_visible_to_recruiters', true)
          .order('created_at', ascending: false);

      if (mounted) {
        final fetched = List<Map<String, dynamic>>.from(response as List);
        setState(() {
          _candidates = fetched;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading candidates: $e');
      if (mounted) {
        setState(() {
          _candidates = [];
          _isLoading = false;
        });
      }
    }
  }

  void _showRegistrationSheet(Map<String, dynamic> candidate) {
    final fullName = candidate['full_name'] ?? 'ce candidat';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 36.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          ),
          child: SingleChildScrollView(
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
                  'Connexion requise',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'Veuillez vous connecter ou créer un compte Recruteur pour pouvoir contacter $fullName.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 28.h),

                // Auth CTA
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/recruiter-auth');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 54.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: Text(
                    'Se connecter / S\'inscrire',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),

                // Cancel button
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Continuer l\'exploration',
                    style: TextStyle(
                      color: const Color(0xFF64748B),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAuthRequiredBottomSheetForTab(String tabName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 36.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.w,
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  'Connexion requise',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'Veuillez vous connecter ou créer un compte Recruteur pour accéder à la rubrique $tabName.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 28.h),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/recruiter-auth');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 54.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: Text(
                    'Se connecter / S\'inscrire',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Continuer la navigation',
                    style: TextStyle(
                      color: const Color(0xFF64748B),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Dénicher des Talents',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF97316)),
            )
          : _candidates.isEmpty
              ? Center(
                  child: Text(
                    'Aucun candidat disponible.',
                    style: TextStyle(fontSize: 16.sp, color: Colors.grey),
                  ),
                )
              : Column(
                  children: [
                    SizedBox(height: 16.h),
                    
                    // The Swipe Deck of blurred CVs
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
                              if (direction == CardSwiperDirection.right) {
                                _showRegistrationSheet(candidate);
                              }
                              setState(() {
                                _dragDirection = CardSwiperDirection.none;
                              });
                              return true;
                            },
                            onSwipeDirectionChange: (horizontal, vertical) {
                              setState(() {
                                _dragDirection = horizontal;
                              });
                            },
                            numberOfCardsDisplayed: _candidates.length >= 3 ? 3 : _candidates.length,
                            backCardOffset: const Offset(0, 40),
                            duration: const Duration(milliseconds: 250),
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            scale: 0.9,
                            maxAngle: 30,
                            threshold: 40,
                            isLoop: true, // Let them loop so they can keep exploring blurred CVs
                            cardBuilder: (context, index, horizontalPercent, verticalPercent) {
                              final candidate = _candidates[index];
                              return CandidateCvSwipeCard(
                                fullName: candidate['full_name'] ?? 'Candidat',
                                skills: List<String>.from(candidate['skills'] ?? []),
                                biography: candidate['biography'],
                                cvUrl: candidate['cv_url'],
                                sexe: candidate['sexe'],
                                isBlurred: false, // Unblurred CV as requested
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // Swipe Action Buttons (Like / Dislike)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Dislike button
                          _buildActionButton(
                            icon: Icons.close_rounded,
                            color: Colors.red,
                            isHighlighted: _dragDirection == CardSwiperDirection.left,
                            onTap: () => _controller.swipe(CardSwiperDirection.left),
                          ),
                          SizedBox(width: 32.w),
                          // Like button
                          _buildActionButton(
                            icon: Icons.favorite_rounded,
                            color: Colors.green,
                            isHighlighted: _dragDirection == CardSwiperDirection.right,
                            onTap: () => _controller.swipe(CardSwiperDirection.right),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          if (index == 0) {
            setState(() => _selectedIndex = 0);
          } else {
              final String tabName = index == 1 ? 'Offres' : 'Profil';
            _showAuthRequiredBottomSheetForTab(tabName);
          }
        },
        indicatorColor: const Color(0xFF1E3A8A).withOpacity(0.1),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_alt_rounded),
            selectedIcon: Icon(Icons.people_alt_rounded, color: Color(0xFF1E3A8A)),
            label: 'Candidats',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle, color: Color(0xFF1E3A8A)),
              label: 'Offres',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Color(0xFF1E3A8A)),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required bool isHighlighted,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 64.r,
        height: 64.r,
        decoration: BoxDecoration(
          color: isHighlighted ? color : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
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
          size: 28.r,
        ),
      ),
    );
  }
}
