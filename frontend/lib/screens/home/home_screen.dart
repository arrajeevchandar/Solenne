import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/journals/journal_dashboard.dart';
import '../../features/journals/journal_day.dart';
import '../../features/journals/journal_entry.dart';
import '../../features/journals/journal_repository.dart';
import '../../routing/fade_through_route.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_screen.dart';
import '../journals/journal_day_navigation.dart';
import '../profile/profile_screen.dart';
import '../recording/recording_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback? onOpenRecording;
  final VoidCallback? onOpenProfile;

  const HomeScreen({super.key, this.onOpenRecording, this.onOpenProfile});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _roomController;

  @override
  void initState() {
    super.initState();
    _roomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 15000),
    )..repeat();
  }

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }

  void _openRecording() {
    if (widget.onOpenRecording != null) {
      widget.onOpenRecording!();
      return;
    }
    Navigator.of(context).push(fadeThroughRoute(const RecordingScreen()));
  }

  void _openProfile() {
    if (widget.onOpenProfile != null) {
      widget.onOpenProfile!();
      return;
    }
    Navigator.of(context).push(fadeThroughRoute(const ProfileScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref
        .watch(journalStreamProvider)
        .when(
          data: (value) => value,
          loading: () => const <JournalEntry>[],
          error: (_, _) => const <JournalEntry>[],
        );
    final dashboard = JournalDashboard(entries);
    return Scaffold(
      body: SizedBox.expand(
        child: SolenneBackground(
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _roomController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _DailySkyPainter(
                        progress: _roomController.value,
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HomeHeader(onProfileTap: _openProfile),
                      const SizedBox(height: 18),
                      _PromptRecordCard(onTap: _openRecording),
                      const SizedBox(height: 22),
                      _MetricTiles(dashboard: dashboard),
                      const SizedBox(height: 22),
                      _ReflectionCurveCard(
                        reflection: dashboard.reflectionText,
                        points: dashboard.valencePoints,
                      ),
                      const SizedBox(height: 14),
                      const _RecentJournalsCard(),
                      const SizedBox(height: 14),
                      AnimatedBuilder(
                        animation: _roomController,
                        builder: (context, _) {
                          return _QuietOrbCard(
                            progress: _roomController.value,
                            weather: dashboard.weatherText,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends ConsumerWidget {
  final VoidCallback onProfileTap;

  const _HomeHeader({required this.onProfileTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(firebaseAuthProvider);
    final firestore = ref.watch(firestoreProvider);
    final user = auth.currentUser;
    final directName = _cleanName(user?.displayName);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (directName != null)
                Text(
                  _greeting(directName),
                  style: AppTextStyles.display(fontSize: 34),
                )
              else if (user == null)
                Text(
                  _greeting('friend'),
                  style: AppTextStyles.display(fontSize: 34),
                )
              else
                FutureBuilder(
                  future: firestore.collection('users').doc(user.uid).get(),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data();
                    final fallbackName = _cleanName(
                      data == null ? null : data['displayName'] as String?,
                    );
                    return Text(
                      _greeting(fallbackName ?? 'friend'),
                      style: AppTextStyles.display(fontSize: 34),
                    );
                  },
                ),
              const SizedBox(height: 4),
              Text(
                _formattedDate(DateTime.now()),
                style: AppTextStyles.mono(
                  fontSize: 11,
                  color: AppColors.shellstone.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
        ),
        _GlassIconButton(
          icon: Icons.person_rounded,
          onTap: () => _showProfileMenu(context, ref),
        ),
      ],
    );
  }

  Future<void> _showProfileMenu(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.36),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: SolenneGlass(
              borderRadius: 24,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ProfileMenuRow(
                    icon: Icons.edit_rounded,
                    label: 'Edit profile',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onProfileTap();
                    },
                  ),
                  const SizedBox(height: 10),
                  _ProfileMenuRow(
                    icon: Icons.logout_rounded,
                    label: 'Log out',
                    isDestructive: true,
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
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
          ),
        );
      },
    );
  }

  static String _greeting(String name) {
    return 'Hello, $name';
  }

  static String? _cleanName(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static String _formattedDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}.';
  }
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? AppColors.electricGold.withValues(alpha: 0.9)
        : AppColors.shellstone.withValues(alpha: 0.9);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.sapphire.withValues(alpha: 0.16),
          border: Border.all(
            color: AppColors.shellstone.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body(fontSize: 14, color: color),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.shellstone.withValues(alpha: 0.42),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptRecordCard extends StatelessWidget {
  final VoidCallback onTap;

  const _PromptRecordCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      borderRadius: 24,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: AppColors.quicksand.withValues(alpha: 0.76),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "What's been on your mind today?",
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.shellstone.withValues(alpha: 0.82),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.shellstone.withValues(alpha: 0.5),
                ),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.quicksand.withValues(alpha: 0.84),
                    AppColors.shellstone.withValues(alpha: 0.72),
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.videocam_rounded,
                    size: 19,
                    color: AppColors.royalBlue.withValues(alpha: 0.92),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Record today's entry",
                    style: AppTextStyles.mono(
                      fontSize: 12,
                      color: AppColors.royalBlue.withValues(alpha: 0.94),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: AppColors.royalBlue.withValues(alpha: 0.92),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTiles extends StatelessWidget {
  const _MetricTiles({required this.dashboard});

  final JournalDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            icon: Icons.video_library_outlined,
            label: 'Sessions',
            value: '${dashboard.sessions}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            icon: Icons.local_fire_department_outlined,
            label: 'Streak',
            value: '${dashboard.streak} days',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            icon: Icons.auto_awesome_motion_outlined,
            label: 'This week',
            value: '${dashboard.thisWeek}',
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Column(
        children: [
          Icon(
            icon,
            size: 24,
            color: AppColors.quicksand.withValues(alpha: 0.72),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.body(
              fontSize: 19,
              color: AppColors.swanWing.withValues(alpha: 0.94),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.mono(
              fontSize: 9,
              color: AppColors.shellstone.withValues(alpha: 0.74),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ReflectionCurveCard extends StatelessWidget {
  final String reflection;
  final List<double> points;

  const _ReflectionCurveCard({required this.reflection, required this.points});

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      borderRadius: 24,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Today in motion',
                  style: AppTextStyles.body(
                    fontSize: 18,
                    color: AppColors.swanWing.withValues(alpha: 0.94),
                  ),
                ),
              ),
              Text(
                'quietly noticed',
                style: AppTextStyles.mono(
                  fontSize: 9,
                  color: AppColors.quicksand.withValues(alpha: 0.54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reflection,
            style: AppTextStyles.body(
              fontSize: 14,
              color: AppColors.shellstone.withValues(alpha: 0.82),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 116,
            width: double.infinity,
            child: CustomPaint(painter: _ReflectionCurvePainter(points)),
          ),
        ],
      ),
    );
  }
}

class _RecentJournalsCard extends ConsumerWidget {
  const _RecentJournalsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journalState = ref.watch(journalStreamProvider);
    return _GlassSurface(
      borderRadius: 24,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Recent journals'),
          const SizedBox(height: 14),
          journalState.when(
            loading: () => const _RecentJournalState(
              icon: Icons.hourglass_top_rounded,
              message: 'Gathering your recent reflections…',
              loading: true,
            ),
            error: (_, _) => const _RecentJournalState(
              icon: Icons.cloud_off_outlined,
              message: 'Recent reflections could not be reached.',
            ),
            data: (entries) {
              final days = groupJournalEntries(entries).take(3).toList();
              if (days.isEmpty) {
                return const _RecentJournalState(
                  icon: Icons.video_call_outlined,
                  message: 'Your first recorded day will appear here.',
                );
              }
              return Column(
                children: [
                  for (int index = 0; index < days.length; index++) ...[
                    _JournalRow(
                      day: days[index],
                      onTap: () => openJournalDay(context, days[index]),
                    ),
                    if (index != days.length - 1) const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RecentJournalState extends StatelessWidget {
  const _RecentJournalState({
    required this.icon,
    required this.message,
    this.loading = false,
  });

  final IconData icon;
  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          if (loading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 1.3,
                color: AppColors.quicksand.withValues(alpha: 0.68),
              ),
            )
          else
            Icon(
              icon,
              size: 20,
              color: AppColors.quicksand.withValues(alpha: 0.66),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.shellstone.withValues(alpha: 0.66),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTextStyles.body(
        fontSize: 18,
        color: AppColors.swanWing.withValues(alpha: 0.94),
      ),
    );
  }
}

class _JournalRow extends StatelessWidget {
  final JournalDay day;
  final VoidCallback onTap;

  const _JournalRow({required this.day, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final entry = day.latestEntry;
    final thumbnail = entry.effectiveThumbnailUrl;
    final now = DateTime.now();
    final difference = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(day.date);
    final dayLabel = switch (difference.inDays) {
      0 => 'Today',
      1 => 'Yesterday',
      final days => '$days days ago',
    };
    final minutes = math.max(1, (entry.durationSeconds / 60).ceil());
    final insightMood = entry.aiInsights.isEmpty
        ? null
        : entry.aiInsights.first.moodLabel.trim();
    final mood = entry.moodLabel?.trim().isNotEmpty == true
        ? entry.moodLabel!.trim()
        : insightMood;
    final detail = [
      dayLabel,
      '$minutes min',
      if (day.entryCount > 1) '${day.entryCount} entries',
      if (mood?.isNotEmpty == true) mood!,
    ].join('  ·  ');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 48,
              height: 40,
              color: AppColors.sapphire.withValues(alpha: 0.22),
              child: thumbnail.isEmpty
                  ? Icon(
                      Icons.videocam_outlined,
                      size: 18,
                      color: AppColors.quicksand.withValues(alpha: 0.82),
                    )
                  : Image.network(
                      thumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.videocam_outlined,
                        size: 18,
                        color: AppColors.quicksand.withValues(alpha: 0.82),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayTitle,
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.shellstone.withValues(alpha: 0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: AppTextStyles.mono(
                    fontSize: 9,
                    color: AppColors.shellstone.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.shellstone.withValues(alpha: 0.45),
          ),
        ],
      ),
    );
  }
}

class _QuietOrbCard extends StatelessWidget {
  final double progress;
  final String weather;

  const _QuietOrbCard({required this.progress, required this.weather});

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      borderRadius: 24,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: CustomPaint(
              painter: _EmotionalOrbPainter(progress: progress),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current weather',
                  style: AppTextStyles.mono(
                    fontSize: 10,
                    color: AppColors.quicksand.withValues(alpha: 0.58),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  weather,
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.shellstone.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
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

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SolenneGlass(
        width: 38,
        height: 38,
        padding: EdgeInsets.zero,
        borderRadius: 19,
        child: Icon(
          icon,
          size: 18,
          color: AppColors.shellstone.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}

class _GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const _GlassSurface({
    required this.child,
    required this.padding,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return SolenneGlass(
      padding: padding,
      borderRadius: borderRadius,
      child: child,
    );
  }
}

class _ReflectionCurvePainter extends CustomPainter {
  const _ReflectionCurvePainter(this.points);

  final List<double> points;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = AppColors.shellstone.withValues(alpha: 0.08);

    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.sapphire.withValues(alpha: 0.24),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.82, size.height * 0.18),
              radius: size.width * 0.32,
            ),
          );
    canvas.drawRect(Offset.zero & size, glow);

    if (points.length < 2) return;
    final offsets = List.generate(points.length, (index) {
      final x = index * size.width / (points.length - 1);
      final y = size.height * (0.9 - points[index] * 0.8);
      return Offset(x, y);
    });
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (int i = 1; i < offsets.length; i++) {
      final previous = offsets[i - 1];
      final current = offsets[i];
      final controlX = (previous.dx + current.dx) / 2;
      path.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = AppColors.sapphire.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            AppColors.sapphire.withValues(alpha: 0.88),
            AppColors.shellstone.withValues(alpha: 0.74),
            AppColors.quicksand.withValues(alpha: 0.88),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _ReflectionCurvePainter oldDelegate) =>
      oldDelegate.points != points;
}

class _EmotionalOrbPainter extends CustomPainter {
  final double progress;

  const _EmotionalOrbPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final pulse = math.sin(progress * math.pi * 2);
    final radius = size.shortestSide * (0.23 + pulse * 0.008);
    final time = progress * math.pi * 2;

    canvas.drawCircle(
      center,
      radius * 1.9,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.quicksand.withValues(alpha: 0.1),
            AppColors.sapphire.withValues(alpha: 0.12),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 2.1)),
    );

    canvas.drawCircle(
      center,
      radius * 1.04,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.08, -0.08),
          colors: [
            AppColors.swanWing.withValues(alpha: 0.72),
            AppColors.shellstone.withValues(alpha: 0.34),
            AppColors.sapphire.withValues(alpha: 0.2),
            Colors.transparent,
          ],
          stops: const [0.0, 0.22, 0.62, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.1)),
    );

    for (int i = 0; i < 6; i++) {
      final rotation = time * (0.06 + i * 0.01) + i * math.pi / 4;
      final orbitWidth = radius * (1.48 + (i % 2) * 0.16);
      final orbitHeight = radius * (0.72 + (i % 3) * 0.12);
      final path = Path();
      for (int step = 0; step <= 120; step++) {
        final t = step / 120 * math.pi * 2;
        final x = math.cos(t) * orbitWidth;
        final y = math.sin(t) * orbitHeight;
        final point =
            center +
            Offset(
              x * math.cos(rotation) - y * math.sin(rotation),
              x * math.sin(rotation) + y * math.cos(rotation),
            );
        if (step == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.75
          ..strokeCap = StrokeCap.round
          ..color = AppColors.quicksand.withValues(alpha: 0.08),
      );
    }

    canvas.drawCircle(
      center,
      radius * 0.18,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.swanWing.withValues(alpha: 0.8),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 0.5)),
    );
  }

  @override
  bool shouldRepaint(_EmotionalOrbPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _DailySkyPainter extends CustomPainter {
  final double progress;

  const _DailySkyPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7);
    final time = progress * math.pi * 2;

    for (int i = 0; i < 150; i++) {
      final phase = random.nextDouble() * math.pi * 2;
      final twinkle = 0.5 + 0.22 * math.sin(time + phase);
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        0.22 + random.nextDouble() * 0.75,
        Paint()
          ..color = AppColors.shellstone.withValues(
            alpha: 0.07 + twinkle * 0.16,
          ),
      );
    }

    final lowerGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.sapphire.withValues(alpha: 0.34),
              AppColors.royalBlue.withValues(alpha: 0.16),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.55, size.height * 0.62),
              radius: size.shortestSide * 0.88,
            ),
          );
    canvas.drawRect(Offset.zero & size, lowerGlow);

    final horizonPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          AppColors.sapphire.withValues(alpha: 0.14),
          AppColors.sapphire.withValues(alpha: 0.1),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    final path = Path()
      ..moveTo(-20, size.height * 0.54)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.48,
        size.width + 20,
        size.height * 0.56,
      )
      ..lineTo(size.width + 20, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.68,
        -20,
        size.height * 0.74,
      )
      ..close();
    canvas.drawPath(path, horizonPaint);
  }

  @override
  bool shouldRepaint(_DailySkyPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
