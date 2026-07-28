import 'package:flutter/material.dart';
import 'package:djossimatch/features/recruiter/presentation/recruiter_swipe_screen.dart';
import 'package:djossimatch/features/matches/presentation/chats_list_screen.dart';
import 'package:djossimatch/features/auth/presentation/recruiter_post_job_screen.dart';
import 'package:djossimatch/features/recruiter/presentation/recruiter_profile_screen.dart';

class RecruiterNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const RecruiterNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<RecruiterNavigationScreen> createState() =>
      _RecruiterNavigationScreenState();
}

class _RecruiterNavigationScreenState extends State<RecruiterNavigationScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 3);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    // Corporate blue theme color
    final Color recruiterThemeColor = const Color(0xFF1E3A8A);

    return Scaffold(
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              labelType: NavigationRailLabelType.all,
              selectedIconTheme: IconThemeData(color: recruiterThemeColor),
              selectedLabelTextStyle: TextStyle(
                color: recruiterThemeColor,
                fontWeight: FontWeight.bold,
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.people_alt_rounded),
                  label: Text('Candidats'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.chat_bubble_outline_rounded),
                  label: Text('Messagerie'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.add_circle_outline),
                  label: Text('Offres'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person),
                  label: Text('Profil'),
                ),
              ],
            ),
          if (isWide) const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                const RecruiterSwipeScreen(embedInNavBar: true),
                const ChatsListScreen(embedInNavBar: true),
                const RecruiterPostJobScreen(embedInNavBar: true),
                const RecruiterProfileScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: !isWide
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              indicatorColor: recruiterThemeColor.withValues(alpha: 0.1),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.people_alt_rounded),
                  selectedIcon: Icon(
                    Icons.people_alt_rounded,
                    color: Color(0xFF1E3A8A),
                  ),
                  label: 'Candidats',
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline_rounded),
                  selectedIcon: Icon(
                    Icons.chat_bubble_rounded,
                    color: Color(0xFF1E3A8A),
                  ),
                  label: 'Messagerie',
                ),
                NavigationDestination(
                  icon: Icon(Icons.add_circle_outline),
                  selectedIcon: Icon(
                    Icons.add_circle,
                    color: Color(0xFF1E3A8A),
                  ),
                  label: 'Offres',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person, color: Color(0xFF1E3A8A)),
                  label: 'Profil',
                ),
              ],
            )
          : null,
    );
  }
}
