import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final index =
        location.startsWith('/timeline') || location.startsWith('/journals')
        ? 1
        : location.startsWith('/record')
        ? 2
        : location.startsWith('/insights')
        ? 3
        : location.startsWith('/profile')
        ? 4
        : 0;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        backgroundColor: AppColors.royalBlue.withValues(alpha: 0.96),
        indicatorColor: AppColors.quicksand.withValues(alpha: 0.22),
        shadowColor: Colors.black.withValues(alpha: 0.5),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(color: AppColors.textPrimary, fontSize: 12),
        ),
        onDestinationSelected: (value) {
          switch (value) {
            case 0:
              context.go('/home');
            case 1:
              context.go('/timeline');
            case 2:
              context.go('/record');
            case 3:
              context.go('/insights');
            case 4:
              context.go('/profile');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.spa_outlined),
            selectedIcon: Icon(Icons.spa),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
            label: 'Timeline',
          ),
          NavigationDestination(
            icon: Icon(Icons.radio_button_checked),
            label: 'Record',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
