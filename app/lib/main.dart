import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:djossimatch/core/theme/app_theme.dart';
import 'package:djossimatch/features/swipe/presentation/swipe_screen.dart';
import 'package:djossimatch/features/matches/presentation/matches_screen.dart';
import 'package:djossimatch/features/profile/presentation/profile_screen.dart';
import 'package:djossimatch/core/routing/app_router.dart';
import 'package:djossimatch/core/services/version_service.dart';
import 'package:djossimatch/core/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:upgrader/upgrader.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await dotenv.load(fileName: ".env");

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    throw Exception(
      'Les clés Supabase sont introuvables dans le fichier .env (SUPABASE_URL et SUPABASE_ANON_KEY)',
    );
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  // Initialisation de Firebase
  try {
    await Firebase.initializeApp(
       options: DefaultFirebaseOptions.currentPlatform,
    );
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  runApp(const DjorssiMatchApp());
}

class DjorssiMatchApp extends StatefulWidget {
  const DjorssiMatchApp({super.key});

  @override
  State<DjorssiMatchApp> createState() => _DjorssiMatchAppState();
}

class _DjorssiMatchAppState extends State<DjorssiMatchApp> {
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        AppRouter.router.go('/reset-password');
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'Djorssi-Match',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          routerConfig: AppRouter.router,
          builder: (context, routerChild) {
            final mediaQuery = MediaQuery.of(context);
            final scale = mediaQuery.textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.15,
            );
            return MediaQuery(
              data: mediaQuery.copyWith(textScaler: scale),
              child: routerChild!,
            );
          },
        );
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _selectedIndex;

  // On pré-initialise les écrans pour éviter de les recréer à chaque build
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _screens = [
      const SwipeScreen(),
      const MatchesScreen(),
      const ProfileScreen(),
    ];

    // Vérifier la version et mettre à jour le token de notification
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VersionService.checkVersion(context);
      NotificationService.updateToken();
    });
  }

  @override
  void didUpdateWidget(MainNavigationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      setState(() {
        _selectedIndex = widget.initialIndex;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;

        return UpgradeAlert(
          dialogStyle: UpgradeDialogStyle.cupertino,
          showIgnore: false,
          showLater: true,
          barrierDismissible: true,
          upgrader: Upgrader(
            debugDisplayAlways: false,
            debugLogging: false,
            durationUntilAlertAgain: const Duration(days: 1),
            messages: UpgraderMessages(code: 'fr'),
          ),
          child: Scaffold(
          body: Row(
            children: [
              if (isWide)
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onItemTapped,
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.swipe),
                      label: Text('Offres'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.favorite),
                      label: Text('Matches'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person),
                      label: Text('Profil'),
                    ),
                  ],
                ),
              if (isWide) const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: SafeArea(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _screens,
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: !isWide
              ? NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onItemTapped,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.swipe),
                      label: 'Offres',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.favorite),
                      label: 'Matches',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person),
                      label: 'Profil',
                    ),
                  ],
                )
              : null,
        ),
      );
      },
    );
  }
}
