import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/profile_avatar.dart';
import '../features/social/social_repository.dart';
import '../routing/fade_through_route.dart';
import '../theme/app_theme.dart';
import 'home/home_screen.dart';
import 'friends/friends_screen.dart';
import 'insights/insights_screen.dart';
import 'profile/profile_screen.dart';
import 'recording/journal_entry_picker_screen.dart';
import 'timeline/timeline_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(authRepositoryProvider).ensureUserDocument(),
    ).catchError((_) {});
  }

  void _openRecording() {
    Navigator.of(
      context,
    ).push(fadeThroughRoute(const JournalEntryPickerScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final photoUrl = ref.watch(userProfileProvider).value?.photoUrl;
    final requestCount = ref.watch(incomingFriendRequestCountProvider);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            onOpenRecording: _openRecording,
            onOpenProfile: () => setState(() => _index = 4),
          ),
          const TimelineScreen(),
          InsightsScreen(onTalkAboutIt: _openRecording),
          const FriendsScreen(embedded: true),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, 14 + bottomPadding),
        child: SolenneGlass(
          height: 62,
          padding: EdgeInsets.zero,
          borderRadius: 28,
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
                icon: Icons.people_alt_rounded,
                badgeCount: requestCount,
                selected: _index == 3,
                onTap: () => setState(() => _index = 3),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                photoUrl: photoUrl,
                selected: _index == 4,
                onTap: () => setState(() => _index = 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String? photoUrl;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  const _NavItem({
    required this.icon,
    required this.selected,
    required this.onTap,
    this.photoUrl,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 46,
        height: 46,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (photoUrl?.trim().isNotEmpty == true)
              ProfileAvatar(photoUrl: photoUrl, radius: selected ? 13 : 12)
            else
              Icon(
                icon,
                size: selected ? 23 : 21,
                color: selected
                    ? AppColors.quicksand.withValues(alpha: 0.9)
                    : AppColors.shellstone.withValues(alpha: 0.52),
              ),
            if (badgeCount > 0)
              Positioned(
                right: 5,
                top: 5,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 15,
                    minHeight: 15,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.electricGold,
                  ),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: AppTextStyles.mono(
                      fontSize: 7,
                      color: AppColors.royalBlue,
                    ),
                  ),
                ),
              ),
          ],
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
