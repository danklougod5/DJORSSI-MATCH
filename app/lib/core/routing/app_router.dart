import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:djossimatch/features/auth/presentation/auth_screen.dart';
import 'package:djossimatch/features/auth/presentation/onboarding_screen.dart';
import 'package:djossimatch/features/splash/presentation/splash_screen.dart';
import 'package:djossimatch/features/profile/presentation/profile_screen.dart';
import 'package:djossimatch/features/premium/presentation/premium_screen.dart';
import 'package:djossimatch/features/auth/presentation/complete_profile_screen.dart';
import 'package:djossimatch/main.dart'; // To access MainNavigationScreen

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuth = session != null;
      final isGoingToAuth = state.matchedLocation == '/auth';
      final isGoingToSplash = state.matchedLocation == '/splash';

      if (isGoingToSplash) {
        return null;
      }

      if (!isAuth) {
        // Not logged in -> can only be on Splash, Onboarding or Auth
        if (state.matchedLocation != '/splash' && 
            state.matchedLocation != '/onboarding' && 
            state.matchedLocation != '/auth') {
          return '/onboarding';
        }
        return null;
      }

      // Logged in
      if (isGoingToAuth || state.matchedLocation == '/onboarding') {
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
