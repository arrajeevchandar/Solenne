import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../routing/fade_through_route.dart';
import '../../theme/app_theme.dart';
import '../../features/auth/auth_providers.dart';
import '../auth/auth_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _voice = 'Observational';

  @override
  Widget build(BuildContext context) {
    return _CosmicPage(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 106),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Profile',
                      style: AppTextStyles.display(fontSize: 36),
                    ),
                  ),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.quicksand.withValues(
                      alpha: 0.18,
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: AppColors.quicksand.withValues(alpha: 0.86),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Minimal controls. Clear trust.',
                style: AppTextStyles.body(
                  fontSize: 14,
                  color: AppColors.shellstone.withValues(alpha: 0.72),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 24),
              _Glass(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Account'),
                    const SizedBox(height: 14),
                    const _ProfileSummary(),
                    const SizedBox(height: 14),
                    const _SettingsRow(
                      icon: Icons.edit_rounded,
                      label: 'Edit profile',
                      detail: 'Username, name, and photo',
                    ),
                    const SizedBox(height: 12),
                    _SettingsRow(
                      icon: Icons.logout_rounded,
                      label: 'Log out',
                      detail: 'Return to sign in',
                      isDestructive: true,
                      onTap: () async {
                        await ref.read(authRepositoryProvider).signOut();
                        if (!context.mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          fadeThroughRoute(const AuthScreen()),
                          (_) => false,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Glass(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Voice'),
                    const SizedBox(height: 12),
                    _VoiceOption(
                      label: 'Observational',
                      text: 'Just notices, rarely offers warmth.',
                      selected: _voice == 'Observational',
                      onTap: () => setState(() => _voice = 'Observational'),
                    ),
                    _VoiceOption(
                      label: 'Warm',
                      text: 'More relational, uses your name more.',
                      selected: _voice == 'Warm',
                      onTap: () => setState(() => _voice = 'Warm'),
                    ),
                    _VoiceOption(
                      label: 'Sparse',
                      text: 'Almost no generated text, minimal AI voice.',
                      selected: _voice == 'Sparse',
                      onTap: () => setState(() => _voice = 'Sparse'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Glass(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Baseline reset'),
                    const SizedBox(height: 10),
                    Text(
                      'If something major has changed, Solenne can mark a new baseline beginning now. Your history stays preserved and labeled before July 2026.',
                      style: AppTextStyles.body(
                        fontSize: 14,
                        color: AppColors.shellstone.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _SoftButton(label: 'Mark a new baseline'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Glass(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Privacy'),
                    const SizedBox(height: 10),
                    Text(
                      'Solenne analyzes voice, words, timing, and recurring themes to build your personal baseline. Processing happens on-device where possible. Your entries are not shared, not benchmarked against other users, and not sold.',
                      style: AppTextStyles.body(
                        fontSize: 14,
                        color: AppColors.shellstone.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Glass(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _SectionTitle('Entry archive'),
                    SizedBox(height: 10),
                    _ArchiveRow(
                      icon: Icons.audio_file_rounded,
                      label: 'Export audio files',
                    ),
                    SizedBox(height: 10),
                    _ArchiveRow(
                      icon: Icons.description_rounded,
                      label: 'Export text transcripts',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSummary extends ConsumerWidget {
  const _ProfileSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.royalBlue.withValues(alpha: 0.18),
        border: Border.all(color: AppColors.shellstone.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.quicksand.withValues(alpha: 0.18),
            child: Icon(
              Icons.person_rounded,
              color: AppColors.quicksand.withValues(alpha: 0.86),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'username',
                  style: AppTextStyles.body(
                    fontSize: 16,
                    color: AppColors.swanWing.withValues(alpha: 0.92),
                  ),
                ),
                Text(
                  user?.email ?? 'username@email.com',
                  style: AppTextStyles.mono(
                    fontSize: 9,
                    color: AppColors.shellstone.withValues(alpha: 0.54),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final bool isDestructive;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.detail,
    this.isDestructive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? AppColors.quicksand.withValues(alpha: 0.86)
        : AppColors.shellstone.withValues(alpha: 0.86);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.body(fontSize: 14, color: color),
                ),
                Text(
                  detail,
                  style: AppTextStyles.mono(
                    fontSize: 9,
                    color: AppColors.shellstone.withValues(alpha: 0.48),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.shellstone.withValues(alpha: 0.42),
          ),
        ],
      ),
    );
  }
}

class _VoiceOption extends StatelessWidget {
  final String label;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _VoiceOption({
    required this.label,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.quicksand.withValues(alpha: 0.44)
                : AppColors.shellstone.withValues(alpha: 0.13),
          ),
          color: selected
              ? AppColors.quicksand.withValues(alpha: 0.09)
              : AppColors.royalBlue.withValues(alpha: 0.16),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected
                  ? AppColors.quicksand.withValues(alpha: 0.82)
                  : AppColors.shellstone.withValues(alpha: 0.52),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.body(
                      fontSize: 14,
                      color: AppColors.swanWing.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text,
                    style: AppTextStyles.body(
                      fontSize: 12,
                      color: AppColors.shellstone.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ArchiveRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColors.quicksand.withValues(alpha: 0.72),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.body(
              fontSize: 14,
              color: AppColors.shellstone.withValues(alpha: 0.82),
            ),
          ),
        ),
        Icon(
          Icons.arrow_forward_rounded,
          size: 17,
          color: AppColors.shellstone.withValues(alpha: 0.44),
        ),
      ],
    );
  }
}

class _SoftButton extends StatelessWidget {
  final String label;

  const _SoftButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.quicksand.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.quicksand.withValues(alpha: 0.26)),
      ),
      child: Text(
        label,
        style: AppTextStyles.mono(
          fontSize: 10,
          color: AppColors.quicksand.withValues(alpha: 0.78),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.body(
        fontSize: 18,
        color: AppColors.swanWing.withValues(alpha: 0.94),
      ),
    );
  }
}

class _CosmicPage extends StatelessWidget {
  final Widget child;

  const _CosmicPage({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF071127), Color(0xFF0D2147), Color(0xFF143765)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _SkyDustPainter())),
          child,
        ],
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;

  const _Glass({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.shellstone.withValues(alpha: 0.18),
            ),
            color: AppColors.royalBlue.withValues(alpha: 0.22),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SkyDustPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(39);
    for (int i = 0; i < 120; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        0.25 + random.nextDouble() * 0.7,
        Paint()
          ..color = AppColors.shellstone.withValues(
            alpha: 0.06 + random.nextDouble() * 0.15,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
