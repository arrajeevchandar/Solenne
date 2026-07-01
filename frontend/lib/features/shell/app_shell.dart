import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final index = location.startsWith('/journals')
        ? 1
        : location.startsWith('/record')
        ? 2
        : location.startsWith('/profile')
        ? 3
        : 0;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        backgroundColor: AppColors.deepNavy,
        indicatorColor: AppColors.aqua.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(color: AppColors.textPrimary, fontSize: 12),
        ),
        onDestinationSelected: (value) {
          switch (value) {
            case 0:
              context.go('/home');
            case 1:
              context.go('/journals');
            case 2:
              context.go('/record');
            case 3:
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
            label: 'Journals',
          ),
          NavigationDestination(
            icon: Icon(Icons.radio_button_checked),
            label: 'Record',
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
