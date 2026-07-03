import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../routing/fade_through_route.dart';
import '../theme/app_theme.dart';
import 'home/home_screen.dart';
import 'insights/insights_screen.dart';
import 'profile/profile_screen.dart';
import 'recording/recording_screen.dart';
import 'timeline/timeline_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _openRecording() {
    Navigator.of(context).push(fadeThroughRoute(const RecordingScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            onOpenRecording: _openRecording,
            onOpenProfile: () => setState(() => _index = 3),
          ),
          const TimelineScreen(),
          InsightsScreen(onTalkAboutIt: _openRecording),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, 14 + bottomPadding),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppColors.shellstone.withValues(alpha: 0.22),
                ),
                color: AppColors.royalBlue.withValues(alpha: 0.54),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.home_rounded,
                    selected: _index == 0,
                    onTap: () => setState(() => _index = 0),
                  ),
                  _NavItem(
                    icon: Icons.timeline_rounded,
                    selected: _index == 1,
                    onTap: () => setState(() => _index = 1),
                  ),
                  _RecordNavButton(onTap: _openRecording),
                  _NavItem(
                    icon: Icons.auto_awesome_rounded,
                    selected: _index == 2,
                    onTap: () => setState(() => _index = 2),
                  ),
                  _NavItem(
                    icon: Icons.person_rounded,
                    selected: _index == 3,
                    onTap: () => setState(() => _index = 3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 46,
        height: 46,
        child: Icon(
          icon,
          size: selected ? 23 : 21,
          color: selected
              ? AppColors.quicksand.withValues(alpha: 0.9)
              : AppColors.shellstone.withValues(alpha: 0.52),
        ),
      ),
    );
  }
}

class _RecordNavButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RecordNavButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.quicksand.withValues(alpha: 0.88),
              AppColors.sapphire.withValues(alpha: 0.62),
            ],
          ),
        ),
        child: Icon(
          Icons.videocam_rounded,
          color: AppColors.royalBlue.withValues(alpha: 0.92),
          size: 22,
        ),
      ),
    );
  }
}
