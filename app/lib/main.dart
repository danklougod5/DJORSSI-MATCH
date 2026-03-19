import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:djossimatch/core/theme/app_theme.dart';
import 'package:djossimatch/features/swipe/presentation/swipe_screen.dart';
import 'package:djossimatch/features/matches/presentation/matches_screen.dart';
import 'package:djossimatch/features/profile/presentation/profile_screen.dart';
import 'package:djossimatch/core/routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://tbhxbfunyhbrctzfpkwf.supabase.co',
    anonKey: 'sb_publishable_4rKluxoXhTD11egNVta7Dw_tdGicphB',
  );

  runApp(const DjossiMatchApp());
}

class DjossiMatchApp extends StatefulWidget {
  const DjossiMatchApp({super.key});

  @override
  State<DjossiMatchApp> createState() => _DjossiMatchAppState();
}

class _DjossiMatchAppState extends State<DjossiMatchApp> {
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
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
          title: 'Djossi Match',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          routerConfig: AppRouter.router,
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

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  List<Widget> _getScreens() => [
    SwipeScreen(),
    MatchesScreen(),
    ProfileScreen(),
  ];

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

        return Scaffold(
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
                child: SafeArea(child: _getScreens()[_selectedIndex]),
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
        );
      },
    );
  }
}
