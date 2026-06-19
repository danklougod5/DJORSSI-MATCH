import 'dart:typed_data';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:djossimatch/features/auth/presentation/auth_screen.dart';
import 'package:djossimatch/features/auth/presentation/onboarding_screen.dart';
import 'package:djossimatch/features/splash/presentation/splash_screen.dart';
import 'package:djossimatch/features/premium/presentation/premium_screen.dart';
import 'package:djossimatch/features/auth/presentation/otp_screen.dart';
import 'package:djossimatch/features/auth/presentation/complete_profile_screen.dart';
import 'package:djossimatch/features/auth/presentation/reset_password_screen.dart';
import 'package:djossimatch/features/auth/presentation/recruiter_post_job_screen.dart';
import 'package:djossimatch/features/profile/presentation/job_alerts_screen.dart';
import 'package:djossimatch/features/profile/presentation/support_qna_screen.dart';
import 'package:djossimatch/features/matches/presentation/match_details_screen.dart';
import 'package:djossimatch/features/notifications/presentation/notification_screen.dart';
import 'package:djossimatch/core/services/version_service.dart';
import 'package:djossimatch/main.dart'; // To access MainNavigationScreen
import 'package:djossimatch/features/cv_generator/screens/cv_builder_screen.dart';
import 'package:djossimatch/features/cv_generator/screens/cv_preview_screen.dart';
import 'package:djossimatch/features/cv_generator/screens/cv_template_selection_screen.dart';
import 'package:djossimatch/features/cv_generator/screens/cv_landing_screen.dart';
import 'package:djossimatch/features/cv_generator/screens/cv_list_screen.dart';
import 'package:djossimatch/features/cv_generator/screens/cv_pdf_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:djossimatch/features/cv_generator/models/cv_model.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuth = session != null;
      final isGoingToAuth = state.matchedLocation == '/auth';
      final isGoingToSplash = state.matchedLocation == '/splash';
      final isResetPassword = state.matchedLocation == '/reset-password';
      final isGoingToPremium = state.matchedLocation == '/premium';

      // Bloquer l'accès à Premium si désactivé à distance (validation Apple)
      if (isGoingToPremium && !VersionService.showPremium) {
        return '/';
      }

      if (isGoingToSplash) {
        return null;
      }

      if (isResetPassword) {
        return null; // Always allow the reset password screen
      }

      if (!isAuth) {
        // Not logged in -> can only be on Splash, Onboarding, Auth, OTP or RecruiterPost
        if (state.matchedLocation != '/splash' &&
            state.matchedLocation != '/onboarding' &&
            state.matchedLocation != '/auth' &&
            state.matchedLocation != '/otp' &&
            state.matchedLocation != '/reset-password' &&
            state.matchedLocation != '/recruiter-post') {
          return '/onboarding';
        }
        return null;
      }

      // Logged in
      if (isGoingToAuth ||
          state.matchedLocation == '/onboarding' ||
          state.matchedLocation == '/otp') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/recruiter-post',
        builder: (context, state) => const RecruiterPostJobScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>?;
          return OtpScreen(
            email: extras?['email'] ?? '',
            fullName: extras?['fullName'],
          );
        },
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/complete-profile',
        builder: (context, state) => const CompleteProfileScreen(),
      ),
      GoRoute(
        path: '/premium',
        builder: (context, state) => const PremiumScreen(),
      ),
      GoRoute(
        path: '/job-alerts',
        builder: (context, state) => const JobAlertsScreen(),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportQnaScreen(),
      ),
      GoRoute(
        path: '/match-details',
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>?;
          return MatchDetailsScreen(match: extras?['match'] ?? {});
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          final jobId = state.uri.queryParameters['job_id'];
          final initialIndex = tab == 'profile'
              ? 3
              : (tab == 'matches' ? 1 : (tab == 'cv' ? 2 : 0));
          return MainNavigationScreen(initialIndex: initialIndex, initialJobId: jobId);
        },
      ),
      // CV Generator: List of saved CVs (main entry point)
      GoRoute(
        path: '/cv_form',
        builder: (context, state) => const CvListScreen(),
      ),
      // CV Generator: Landing screen (choice between AI import or manual)
      GoRoute(
        path: '/cv_landing',
        builder: (context, state) {
          final autoImport = state.uri.queryParameters['auto_import'] == 'true';
          final pdfBytes = state.extra as Uint8List?;
          return CvLandingScreen(autoImport: autoImport, pdfBytes: pdfBytes);
        },
      ),
      // CV Generator: Template & color selection
      GoRoute(
        path: '/cv_template_select',
        builder: (context, state) {
          final cv = state.extra as CvModel?;
          return CvTemplateSelectionScreen(existingCv: cv);
        },
      ),
      GoRoute(
        path: '/cv_builder',
        builder: (context, state) {
          final cv = state.extra as CvModel?;
          return CvBuilderScreen(initialCv: cv);
        },
      ),
      GoRoute(
        path: '/cv_preview',
        builder: (context, state) {
          final cv = state.extra as CvModel;
          final allowEdit = state.uri.queryParameters['allow_edit'] == 'true';
          return CvPreviewScreen(cv: cv, allowEdit: allowEdit);
        },
      ),
      GoRoute(
        path: '/cv_pdf_viewer',
        builder: (context, state) {
          final pdfUrl = state.uri.queryParameters['url'] ?? '';
          final title = state.uri.queryParameters['title'] ?? 'Mon CV';
          return CvPdfViewerScreen(pdfUrl: pdfUrl, title: title);
        },
      ),
    ],
  );
}
