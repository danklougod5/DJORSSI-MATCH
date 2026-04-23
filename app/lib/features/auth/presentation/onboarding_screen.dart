import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:djossimatch/features/auth/presentation/widgets/automatic_postulation_visual.dart';
import 'package:djossimatch/features/auth/presentation/widgets/swipe_onboarding_visual.dart';
import 'package:djossimatch/features/auth/presentation/widgets/match_onboarding_visual.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildSlide(
                    customVisual: const SwipeOnboardingVisual(),
                    title: 'Swippez les meilleures offres',
                    description:
                        'À droite pour postuler, à gauche pour ignorer. C\'est aussi simple que ça.',
                  ),
                  _buildSlide(
                    customVisual: const AutomaticPostulationVisual(),
                    title: 'Swipez, c\'est postulé !',
                    description:
                        'En swipant à droite, votre CV et votre lettre de motivation sont envoyés instantanément au recruteur.',
                  ),
                  _buildSlide(
                    customVisual: const MatchOnboardingVisual(),
                    title: 'Un match = Une postulation',
                    description:
                        'Dès qu\'un recruteur valide votre profil, c\'est un match ! Cela signifie que vous avez postulé avec succès.',
                  ),
                ],
              ),
            ),
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide({
    String? image,
    Widget? customVisual,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (customVisual != null)
            customVisual
          else
            Image.asset(
              'assets/images/$image.png',
              height: 280.h,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                image?.contains('swipe') == true ? Icons.swipe : Icons.favorite,
                size: 150.r,
                color: const Color(0xFFF97316).withOpacity(0.2),
              ),
            ),
          SizedBox(height: 48.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
              height: 1.2,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              color: const Color(0xFF64748B),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Padding(
      padding: EdgeInsets.all(32.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalPages, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                height: 8.h,
                width: _currentPage == index ? 24.w : 8.w,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? const Color(0xFFF97316)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4.r),
                ),
              );
            }),
          ),
          SizedBox(height: 32.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_currentPage < _totalPages - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                } else {
                  context.go('/auth');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 20.h),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.r),
                ),
              ),
              child: Text(
                _currentPage < _totalPages - 1 ? 'SUIVANT' : 'COMMENCER',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
