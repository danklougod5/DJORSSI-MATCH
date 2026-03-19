import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:djossimatch/features/auth/presentation/auth_screen.dart';
import 'package:djossimatch/features/auth/presentation/onboarding_screen.dart';
import 'package:djossimatch/features/splash/presentation/splash_screen.dart';
import 'package:djossimatch/features/profile/presentation/profile_screen.dart';
import 'package:djossimatch/features/premium/presentation/premium_screen.dart';
import 'package:djossimatch/features/auth/presentation/otp_screen.dart';
import 'package:djossimatch/features/auth/presentation/complete_profile_screen.dart';
import 'package:djossimatch/features/auth/presentation/reset_password_screen.dart';
import 'package:djossimatch/features/profile/presentation/job_alerts_screen.dart';
import 'package:djossimatch/main.dart'; // To access MainNavigationScreen

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuth = session != null;
      final isGoingToAuth = state.matchedLocation == '/auth';
      final isGoingToSplash = state.matchedLocation == '/splash';
      final isResetPassword = state.matchedLocation == '/reset-password';

      if (isGoingToSplash) {
        return null;
      }

      if (isResetPassword) {
        return null; // Always allow the reset password screen
      }

      if (!isAuth) {
        // Not logged in -> can only be on Splash, Onboarding, Auth or OTP
        if (state.matchedLocation != '/splash' && 
            state.matchedLocation != '/onboarding' && 
            state.matchedLocation != '/auth' &&
            state.matchedLocation != '/otp' &&
            state.matchedLocation != '/reset-password') {
          return '/onboarding';
        }
        return null;
      }

      // Logged in
      if (isGoingToAuth || state.matchedLocation == '/onboarding' || state.matchedLocation == '/otp') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
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
        path: '/',
        builder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          final initialIndex = tab == 'profile' ? 2 : (tab == 'matches' ? 1 : 0);
          return MainNavigationScreen(initialIndex: initialIndex);
        },
      ),
    ],
  );
}
