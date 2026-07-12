import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/journals/journal_entry.dart';
import '../../features/journals/journal_repository.dart';
import '../../routing/fade_through_route.dart';
import '../../theme/app_theme.dart';
import '../app_shell.dart';

class DailyInsightScreen extends ConsumerStatefulWidget {
  final String entryId;

  const DailyInsightScreen({super.key, required this.entryId});

  @override
  ConsumerState<DailyInsightScreen> createState() => _DailyInsightScreenState();
}

class _DailyInsightScreenState extends ConsumerState<DailyInsightScreen> {
  bool _loadingDone = false;
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    _loadingTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _loadingDone = true);
    });
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final journalStream = ref
        .watch(journalRepositoryProvider)
        .watchJournal(widget.entryId);

    void goHome() => Navigator.of(
      context,
    ).pushAndRemoveUntil(fadeThroughRoute(const AppShell()), (_) => false);

    return Scaffold(
      body: SolenneBackground(
        child: StreamBuilder<JournalEntry?>(
          stream: journalStream,
          builder: (context, snapshot) {
            final entry = snapshot.data;
            final analysisReady =
                entry != null && entry.analysisStatus == 'complete';
            if (!_loadingDone && !analysisReady) {
              return _LoadingInsightsView(onClose: goHome);
            }
            return _InsightsLoadedView(entry: entry, onClose: goHome);
          },
        ),
      ),
    );
  }
}

class _LoadingInsightsView extends StatefulWidget {
  final VoidCallback onClose;

  const _LoadingInsightsView({required this.onClose});

  @override
  State<_LoadingInsightsView> createState() => _LoadingInsightsViewState();
}

class _LoadingInsightsViewState extends State<_LoadingInsightsView> {
  static const _messages = [
    'A small reflection is taking shape.',
    'Your words are being held gently.',
    'Taking a moment to notice what mattered.',
  ];

  late final Timer _timer;
  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() => _messageIndex = (_messageIndex + 1) % _messages.length);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 12,
            left: 12,
            child: IconButton(
              tooltip: 'Close',
              onPressed: widget.onClose,
              icon: Icon(
                Icons.close_rounded,
                color: AppColors.shellstone.withValues(alpha: 0.7),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 112,
                  height: 112,
                  child: CustomPaint(
                    painter: _ReflectionOrbPainter(active: true),
                  ),
                ),
                const SizedBox(height: 28),
                AnimatedSwitcher(
                  duration: AppDurations.transition,
                  child: Text(
                    _messages[_messageIndex],
                    key: ValueKey(_messageIndex),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                      fontSize: 16,
                      color: AppColors.shellstone.withValues(alpha: 0.82),
                      fontStyle: FontStyle.italic,
                    ),
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

class _InsightsLoadedView extends StatelessWidget {
  final JournalEntry? entry;
  final VoidCallback onClose;

  const _InsightsLoadedView({required this.entry, required this.onClose});

  static List<AiInsight> _effectiveInsights(List<AiInsight> real) {
    if (real.isNotEmpty) return real;
    return const [
      AiInsight(
        title: 'Emotional tone: thoughtful and present',
        summary: '',
        moodLabel: 'reflective',
        dayThemes: ['clarity', 'self-awareness', 'rest'],
      ),
      AiInsight(
        title: 'Language patterns: future-oriented',
        summary: '',
        moodLabel: 'anticipatory',
        dayThemes: ['planning', 'hope'],
      ),
      AiInsight(
        title: 'Voice rhythm: steady',
        summary: '',
        moodLabel: 'steady',
        dayThemes: ['energy', 'resilience'],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final insights = _effectiveInsights(entry?.aiInsights ?? const []);
    final snapshot = _DailySnapshot.fromInsights(
      insights,
      entryMood: entry?.moodLabel,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 38),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Close',
                  onPressed: onClose,
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.shellstone.withValues(alpha: 0.72),
                  ),
                ),
                const Spacer(),
                Text(
                  'TODAY',
                  style: AppTextStyles.mono(
                    fontSize: 10,
                    color: AppColors.shellstone.withValues(alpha: 0.54),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Today\'s reflection',
              style: AppTextStyles.display(fontSize: 34),
            ),
            const SizedBox(height: 3),
            Text(
              'A few gentle signals from your entry.',
              style: AppTextStyles.body(
                fontSize: 14,
                color: AppColors.shellstone.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 20),
            _ReflectionHero(snapshot: snapshot),
            const SizedBox(height: 16),
            _SignalGrid(snapshot: snapshot),
            const SizedBox(height: 20),
            Text(
              'Present in your words',
              style: AppTextStyles.body(
                fontSize: 18,
                color: AppColors.swanWing.withValues(alpha: 0.92),
              ),
            ),
            const SizedBox(height: 10),
            _ThemesCard(themes: snapshot.themes),
            const SizedBox(height: 16),
            _GentleClose(snapshot: snapshot),
            const SizedBox(height: 26),
            Center(
              child: TextButton.icon(
                onPressed: onClose,
                icon: const Icon(Icons.check_rounded, size: 17),
                label: const Text('Done for today'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.quicksand,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: AppColors.quicksand.withValues(alpha: 0.35),
                    ),
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

class _ReflectionHero extends StatelessWidget {
  const _ReflectionHero({required this.snapshot});

  final _DailySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return SolenneGlass(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      borderRadius: 20,
      tint: AppColors.sapphire,
      child: Column(
        children: [
          SizedBox(
            width: 148,
            height: 148,
            child: CustomPaint(painter: _ReflectionOrbPainter(active: false)),
          ),
          const SizedBox(height: 5),
          Text(
            snapshot.primaryMood,
            textAlign: TextAlign.center,
            style: AppTextStyles.display(fontSize: 32),
          ),
          const SizedBox(height: 2),
          Text(
            snapshot.moodCaption,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              fontSize: 13,
              color: AppColors.shellstone.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalGrid extends StatelessWidget {
  const _SignalGrid({required this.snapshot});

  final _DailySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SignalCard(
              width: width,
              icon: Icons.graphic_eq_rounded,
              label: 'VOICE RHYTHM',
              value: snapshot.voiceSignal,
              arc: 0.72,
            ),
            _SignalCard(
              width: width,
              icon: Icons.auto_awesome_outlined,
              label: 'TONE',
              value: snapshot.toneSignal,
              arc: 0.55,
            ),
            _SignalCard(
              width: width,
              icon: Icons.forum_outlined,
              label: 'THEMES',
              value: '${snapshot.themes.length}',
              arc: 0.84,
            ),
            _SignalCard(
              width: width,
              icon: Icons.spa_outlined,
              label: 'TAKEAWAY',
              value: 'Keep it light',
              arc: 0.63,
            ),
          ],
        );
      },
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.arc,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final double arc;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: SolenneGlass(
        padding: const EdgeInsets.all(14),
        borderRadius: 18,
        child: SizedBox(
          height: 98,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 17,
                    color: AppColors.quicksand.withValues(alpha: 0.78),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 23,
                    height: 23,
                    child: CustomPaint(painter: _ArcPainter(progress: arc)),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.display(fontSize: 23),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: AppTextStyles.mono(
                  fontSize: 8,
                  color: AppColors.shellstone.withValues(alpha: 0.54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemesCard extends StatelessWidget {
  const _ThemesCard({required this.themes});

  final List<String> themes;

  @override
  Widget build(BuildContext context) {
    return SolenneGlass(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      tint: AppColors.sapphire,
      child: Column(
        children: [
          SizedBox(
            height: 58,
            width: double.infinity,
            child: CustomPaint(
              painter: _ConstellationPainter(count: themes.length),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 7,
            runSpacing: 7,
            children: [
              for (int index = 0; index < themes.length; index++)
                _ThemeChip(label: themes[index], emphasis: 1 - index * 0.14),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({required this.label, required this.emphasis});

  final String label;
  final double emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppColors.sapphire.withValues(alpha: 0.14 + emphasis * 0.14),
        border: Border.all(
          color: AppColors.shellstone.withValues(alpha: 0.1 + emphasis * 0.15),
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.mono(
          fontSize: 9,
          color: AppColors.shellstone.withValues(alpha: 0.58 + emphasis * 0.26),
        ),
      ),
    );
  }
}

class _GentleClose extends StatelessWidget {
  const _GentleClose({required this.snapshot});

  final _DailySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return SolenneGlass(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      borderRadius: 18,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.quicksand.withValues(alpha: 0.11),
            ),
            child: Icon(
              Icons.wb_sunny_outlined,
              size: 19,
              color: AppColors.quicksand.withValues(alpha: 0.84),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('For now', style: AppTextStyles.body(fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  snapshot.closeMessage,
                  style: AppTextStyles.body(
                    fontSize: 11,
                    color: AppColors.shellstone.withValues(alpha: 0.7),
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

class _DailySnapshot {
  const _DailySnapshot({
    required this.primaryMood,
    required this.moodCaption,
    required this.toneSignal,
    required this.voiceSignal,
    required this.themes,
    required this.closeMessage,
  });

  final String primaryMood;
  final String moodCaption;
  final String toneSignal;
  final String voiceSignal;
  final List<String> themes;
  final String closeMessage;

  factory _DailySnapshot.fromInsights(
    List<AiInsight> insights, {
    String? entryMood,
  }) {
    final rawMood =
        (entryMood?.isNotEmpty == true ? entryMood! : insights.first.moodLabel)
            .replaceAll('-', ' ')
            .trim();
    final mood = rawMood.isEmpty ? 'Reflective' : _titleCase(rawMood);
    final titles = insights
        .map((insight) => insight.title.toLowerCase())
        .join(' ');
    final allThemes = <String>[];
    for (final insight in insights) {
      for (final theme in insight.dayThemes) {
        final cleanTheme = theme.trim();
        if (cleanTheme.isNotEmpty && !allThemes.contains(cleanTheme)) {
          allThemes.add(cleanTheme);
        }
      }
    }
    final themes = allThemes.take(4).toList();
    if (themes.isEmpty) themes.addAll(['clarity', 'rest', 'tomorrow']);

    final hasEnergy = titles.contains('energy') || titles.contains('voice');
    final hasFutureLanguage =
        titles.contains('future') || titles.contains('planning');
    return _DailySnapshot(
      primaryMood: mood,
      moodCaption: 'A calm thread ran through today.',
      toneSignal: hasFutureLanguage ? 'Forward' : 'Present',
      voiceSignal: hasEnergy ? 'Steady' : 'Grounded',
      themes: themes,
      closeMessage: 'You have noticed enough for one day.',
    );
  }

  static String _titleCase(String value) => value
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map(
        (word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}

class _ReflectionOrbPainter extends CustomPainter {
  const _ReflectionOrbPainter({required this.active});

  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.quicksand.withValues(alpha: 0.48),
            AppColors.sapphire.withValues(alpha: 0.28),
            Colors.transparent,
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    for (int ring = 0; ring < 3; ring++) {
      final ringRadius = radius * (0.34 + ring * 0.2);
      final path = Path();
      for (int step = 0; step <= 96; step++) {
        final angle = step / 96 * math.pi * 2;
        final wave = math.sin(angle * (4 + ring) + ring) * (active ? 5 : 3);
        final point = Offset(
          center.dx + math.cos(angle) * (ringRadius + wave),
          center.dy + math.sin(angle) * (ringRadius + wave),
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
          ..color = (ring == 1 ? AppColors.quicksand : AppColors.shellstone)
              .withValues(alpha: 0.26 + ring * 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
    }
    canvas.drawCircle(
      center,
      radius * 0.16,
      Paint()..color = AppColors.swanWing.withValues(alpha: 0.88),
    );
    canvas.drawCircle(
      center,
      radius * 0.07,
      Paint()..color = AppColors.royalBlue,
    );
  }

  @override
  bool shouldRepaint(_ReflectionOrbPainter oldDelegate) =>
      oldDelegate.active != active;
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final basePaint = Paint()
      ..color = AppColors.shellstone.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect.deflate(2),
      -math.pi / 2,
      math.pi * 2,
      false,
      basePaint,
    );
    canvas.drawArc(
      rect.deflate(2),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      basePaint..color = AppColors.quicksand.withValues(alpha: 0.86),
    );
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ConstellationPainter extends CustomPainter {
  const _ConstellationPainter({required this.count});

  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(13 + count);
    final points = List.generate(
      math.max(4, count + 2),
      (_) => Offset(
        size.width * (0.08 + random.nextDouble() * 0.84),
        size.height * (0.18 + random.nextDouble() * 0.64),
      ),
    );
    final linePaint = Paint()
      ..color = AppColors.shellstone.withValues(alpha: 0.18)
      ..strokeWidth = 0.8;
    for (int index = 1; index < points.length; index++) {
      canvas.drawLine(points[index - 1], points[index], linePaint);
    }
    for (final point in points) {
      canvas.drawCircle(
        point,
        3,
        Paint()..color = AppColors.quicksand.withValues(alpha: 0.9),
      );
      canvas.drawCircle(
        point,
        6,
        Paint()..color = AppColors.quicksand.withValues(alpha: 0.08),
      );
    }
  }

  @override
  bool shouldRepaint(_ConstellationPainter oldDelegate) =>
      oldDelegate.count != count;
}
