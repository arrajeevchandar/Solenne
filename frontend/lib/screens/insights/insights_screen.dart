import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/journals/journal_dashboard.dart';
import '../../features/journals/journal_entry.dart';
import '../../features/journals/journal_repository.dart';
import '../../theme/app_theme.dart';

class InsightsScreen extends ConsumerWidget {
  final VoidCallback onTalkAboutIt;

  const InsightsScreen({super.key, required this.onTalkAboutIt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref
        .watch(journalStreamProvider)
        .when(
          data: (value) => value,
          loading: () => const <JournalEntry>[],
          error: (_, _) => const <JournalEntry>[],
        );
    final dashboard = JournalDashboard(entries);
    final model = _InsightModel.fromDashboard(dashboard);

    return _CosmicPage(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 106),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Insights', style: AppTextStyles.display(fontSize: 36)),
              const SizedBox(height: 4),
              Text(
                'Plain-language signals from your weekly check-ins.',
                style: AppTextStyles.body(
                  fontSize: 14,
                  color: AppColors.shellstone.withValues(alpha: 0.72),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 22),
              _WellbeingSummaryCard(model: model),
              const SizedBox(height: 14),
              _SignalGrid(model: model),
              const SizedBox(height: 14),
              _ExplainabilityCard(model: model),
              const SizedBox(height: 22),
              Text(
                'Patterns Solenne noticed',
                style: AppTextStyles.body(
                  fontSize: 18,
                  color: AppColors.swanWing.withValues(alpha: 0.94),
                ),
              ),
              const SizedBox(height: 12),
              _PatternsCarousel(model: model),
              const SizedBox(height: 18),
              _TalkNudge(onTalkAboutIt: onTalkAboutIt, model: model),
              const SizedBox(height: 16),
              _WordsInView(model: model),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightModel {
  const _InsightModel({
    required this.windowLabel,
    required this.entryCount,
    required this.summaryStatus,
    required this.summary,
    required this.anxietyLevel,
    required this.anxietyReason,
    required this.lowMoodLevel,
    required this.lowMoodReason,
    required this.confidence,
    required this.strongestSignal,
    required this.patterns,
    required this.nudge,
    required this.wordSummary,
    required this.terms,
    required this.valencePoints,
    required this.stressPoints,
  });

  final String windowLabel;
  final int entryCount;
  final String summaryStatus;
  final String summary;
  final String anxietyLevel;
  final String anxietyReason;
  final String lowMoodLevel;
  final String lowMoodReason;
  final double confidence;
  final String strongestSignal;
  final List<String> patterns;
  final String nudge;
  final String wordSummary;
  final List<String> terms;
  final List<double> valencePoints;
  final List<double> stressPoints;

  factory _InsightModel.fromDashboard(JournalDashboard dashboard) {
    final entries = dashboard.insightAnalyzedEntries;
    final stressPoints = dashboard.stressPoints;
    final valencePoints = dashboard.valencePoints;
    final stressAvg = _average(stressPoints);
    final valenceAvg = _average(valencePoints);
    final entryCount = dashboard.insightAnalyzedCount;
    final hasSignals = entries.isNotEmpty;

    final anxietyLevel = !hasSignals
        ? 'Not ready'
        : stressAvg >= 0.66
        ? 'Elevated'
        : stressAvg >= 0.42
        ? 'Moderate'
        : 'Low';
    final lowMoodLevel = !hasSignals
        ? 'Not ready'
        : valenceAvg <= 0.34
        ? 'Elevated'
        : valenceAvg <= 0.48
        ? 'Moderate'
        : 'Low';

    final status = !hasSignals
        ? 'Waiting for signals'
        : anxietyLevel == 'Elevated' || lowMoodLevel == 'Elevated'
        ? 'Needs attention'
        : anxietyLevel == 'Moderate' || lowMoodLevel == 'Moderate'
        ? 'Worth watching'
        : 'Mostly steady';

    final summary = !hasSignals
        ? 'Once a few entries are analyzed, this space will translate your voice and words into a simple weekly wellbeing read.'
        : status == 'Needs attention'
        ? 'Across $entryCount recent entries, Solenne is seeing more heaviness or tension than your steadier baseline. This is not a diagnosis, but it is a signal worth noticing early.'
        : status == 'Worth watching'
        ? 'Across $entryCount recent entries, the signals are mixed: there are some stress or low-energy cues, but not a strong sustained pattern yet.'
        : 'Across $entryCount recent entries, your signals look mostly steady. Solenne is still watching for changes in energy, language, and emotional tone.';

    final anxietyReason = !hasSignals
        ? 'Needs analyzed entries first.'
        : stressAvg >= 0.66
        ? 'Stress-related language and tension cues are appearing more strongly than usual.'
        : stressAvg >= 0.42
        ? 'Some stress cues are present, but they are not dominating the week.'
        : 'Stress cues are present at a lower level in this window.';

    final lowMoodReason = !hasSignals
        ? 'Needs analyzed entries first.'
        : valenceAvg <= 0.34
        ? 'The overall emotional tone has leaned heavier across the recent entries.'
        : valenceAvg <= 0.48
        ? 'There are some quieter emotional cues, but the pattern is not strong.'
        : 'The recent emotional tone is not showing a strong low-mood signal.';

    final strongestSignal = _strongestSignal(anxietyLevel, lowMoodLevel);
    final patterns = _patternsFor(
      dashboard,
      status,
      anxietyLevel,
      lowMoodLevel,
    );
    final terms = dashboard.languageTerms;
    final confidence = (entryCount / 5).clamp(0.0, 1.0).toDouble();

    return _InsightModel(
      windowLabel: dashboard.insightWindowLabel,
      entryCount: entryCount,
      summaryStatus: status,
      summary: summary,
      anxietyLevel: anxietyLevel,
      anxietyReason: anxietyReason,
      lowMoodLevel: lowMoodLevel,
      lowMoodReason: lowMoodReason,
      confidence: confidence,
      strongestSignal: strongestSignal,
      patterns: patterns,
      nudge: dashboard.latestSuggestion,
      wordSummary: _wordSummary(terms),
      terms: terms,
      valencePoints: valencePoints,
      stressPoints: stressPoints,
    );
  }

  static double _average(List<double> values) {
    if (values.isEmpty) return 0.5;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static String _strongestSignal(String anxiety, String lowMood) {
    if (anxiety == 'Not ready') return 'Waiting for enough analyzed entries';
    if (anxiety == 'Elevated' && lowMood == 'Elevated') {
      return 'Both tension and low-mood cues are elevated';
    }
    if (anxiety == 'Elevated') return 'Tension and anxiety-related cues';
    if (lowMood == 'Elevated') return 'Heavier emotional tone';
    if (anxiety == 'Moderate') return 'Mild stress cues';
    if (lowMood == 'Moderate') return 'Mild low-energy cues';
    return 'No strong concern signal in this window';
  }

  static List<String> _patternsFor(
    JournalDashboard dashboard,
    String status,
    String anxiety,
    String lowMood,
  ) {
    final patterns = <String>[];
    if (dashboard.voiceEnergyPoints.length >= 2) {
      patterns.add(
        'Voice energy has been ${_trendLabel(dashboard.voiceEnergyPoints)} across the recent entries.',
      );
    }
    if (dashboard.stressPoints.length >= 2) {
      patterns.add(
        'Stress cues are ${_trendLabel(dashboard.stressPoints)} compared with earlier entries in this window.',
      );
    }
    if (dashboard.recurringThemes.isNotEmpty) {
      final theme = dashboard.recurringThemes.first.key;
      patterns.add(
        'The theme "$theme" is showing up repeatedly, so Solenne is keeping it in view.',
      );
    }
    if (patterns.isEmpty) {
      patterns.add(
        'Solenne needs a few more analyzed entries before naming a reliable pattern.',
      );
    }
    if (status == 'Needs attention') {
      patterns.add(
        'This window contains a stronger wellbeing signal than the usual steady range.',
      );
    } else if (anxiety == 'Low' && lowMood == 'Low') {
      patterns.add(
        'No clear anxiety or low-mood risk pattern is standing out right now.',
      );
    }
    return patterns.take(4).toList(growable: false);
  }

  static String _trendLabel(List<double> points) {
    if (points.length < 2) return 'still forming';
    final delta = points.last - points.first;
    if (delta > 0.14) return 'rising';
    if (delta < -0.14) return 'lowering';
    return 'fairly steady';
  }

  static String _wordSummary(List<String> terms) {
    if (terms.isEmpty) {
      return 'No recurring words are clear enough yet.';
    }
    if (terms.length == 1) {
      return 'The clearest word in view is ${terms.first}.';
    }
    return 'The clearest words in view are ${terms.take(3).join(', ')}.';
  }
}

class _WellbeingSummaryCard extends StatelessWidget {
  const _WellbeingSummaryCard({required this.model});

  final _InsightModel model;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      tint: AppColors.sapphire,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'WEEKLY WELLBEING',
                style: AppTextStyles.mono(
                  fontSize: 10,
                  color: AppColors.quicksand.withValues(alpha: 0.78),
                ),
              ),
              const Spacer(),
              Text(
                model.windowLabel,
                style: AppTextStyles.mono(
                  fontSize: 10,
                  color: AppColors.shellstone.withValues(alpha: 0.58),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  model.summaryStatus,
                  style: AppTextStyles.display(fontSize: 31),
                ),
              ),
              SizedBox(
                width: 68,
                height: 68,
                child: CustomPaint(
                  painter: _SignalOrbPainter(
                    model.valencePoints,
                    model.stressPoints,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            model.summary,
            style: AppTextStyles.body(
              fontSize: 14,
              color: AppColors.shellstone.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalGrid extends StatelessWidget {
  const _SignalGrid({required this.model});

  final _InsightModel model;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _SignalCard(
            icon: Icons.air_rounded,
            label: 'ANXIETY RISK SIGNAL',
            level: model.anxietyLevel,
            reason: model.anxietyReason,
            points: model.stressPoints,
            warm: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SignalCard(
            icon: Icons.nightlight_round,
            label: 'LOW MOOD SIGNAL',
            level: model.lowMoodLevel,
            reason: model.lowMoodReason,
            points: model.valencePoints,
          ),
        ),
      ],
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({
    required this.icon,
    required this.label,
    required this.level,
    required this.reason,
    required this.points,
    this.warm = false,
  });

  final IconData icon;
  final String label;
  final String level;
  final String reason;
  final List<double> points;
  final bool warm;

  @override
  Widget build(BuildContext context) {
    final accent = warm ? AppColors.quicksand : AppColors.sapphire;
    return _Glass(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
      tint: AppColors.royalBlue,
      child: SizedBox(
        height: 154,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: accent.withValues(alpha: 0.78)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.mono(
                      fontSize: 8.5,
                      color: AppColors.shellstone.withValues(alpha: 0.58),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(level, style: AppTextStyles.display(fontSize: 24)),
            const SizedBox(height: 7),
            Text(
              reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(
                fontSize: 10.5,
                color: AppColors.shellstone.withValues(alpha: 0.72),
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 28,
              child: CustomPaint(
                painter: _MiniTrendPainter(points: points, accent: accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExplainabilityCard extends StatelessWidget {
  const _ExplainabilityCard({required this.model});

  final _InsightModel model;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.sapphire.withValues(alpha: 0.18),
              border: Border.all(
                color: AppColors.quicksand.withValues(alpha: 0.24),
              ),
            ),
            child: Text(
              '${(model.confidence * 100).round()}%',
              style: AppTextStyles.mono(
                fontSize: 11,
                color: AppColors.quicksand.withValues(alpha: 0.86),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why Solenne says this',
                  style: AppTextStyles.body(fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  '${model.strongestSignal}. Confidence grows as more entries are analyzed.',
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.shellstone.withValues(alpha: 0.68),
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

class _PatternsCarousel extends StatelessWidget {
  const _PatternsCarousel({required this.model});

  final _InsightModel model;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 174,
      child: PageView(
        controller: PageController(viewportFraction: 0.86),
        padEnds: false,
        children: [
          for (final pattern in model.patterns)
            _PatternCard(text: pattern, points: model.valencePoints),
        ],
      ),
    );
  }
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({required this.text, required this.points});

  final String text;
  final List<double> points;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: _Glass(
        tint: AppColors.sapphire,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OBSERVED PATTERN',
              style: AppTextStyles.mono(
                fontSize: 9,
                color: AppColors.quicksand.withValues(alpha: 0.76),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.body(
                  fontSize: 17,
                  fontStyle: FontStyle.italic,
                  color: AppColors.swanWing.withValues(alpha: 0.88),
                ),
              ),
            ),
            SizedBox(
              height: 30,
              child: CustomPaint(
                painter: _MiniTrendPainter(
                  points: points,
                  accent: AppColors.quicksand,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TalkNudge extends StatelessWidget {
  const _TalkNudge({required this.onTalkAboutIt, required this.model});

  final VoidCallback onTalkAboutIt;
  final _InsightModel model;

  @override
  Widget build(BuildContext context) {
    final showWarm = model.summaryStatus == 'Needs attention';
    return _Glass(
      tint: showWarm ? AppColors.quicksand : AppColors.sapphire,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.quicksand.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.quicksand.withValues(alpha: 0.26),
              ),
            ),
            child: Icon(
              Icons.waves_rounded,
              color: AppColors.quicksand.withValues(alpha: 0.82),
              size: 21,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('A gentle nudge', style: AppTextStyles.body(fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  model.nudge,
                  style: AppTextStyles.body(
                    fontSize: 11,
                    color: AppColors.shellstone.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Talk about it',
            onPressed: onTalkAboutIt,
            icon: const Icon(Icons.arrow_forward_rounded),
            color: AppColors.quicksand,
          ),
        ],
      ),
    );
  }
}

class _WordsInView extends StatelessWidget {
  const _WordsInView({required this.model});

  final _InsightModel model;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WORDS IN VIEW',
            style: AppTextStyles.mono(
              fontSize: 9,
              color: AppColors.quicksand.withValues(alpha: 0.74),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            model.wordSummary,
            style: AppTextStyles.body(
              fontSize: 14,
              color: AppColors.shellstone.withValues(alpha: 0.76),
            ),
          ),
          const SizedBox(height: 12),
          if (model.terms.isEmpty)
            Text(
              'No clear themes yet.',
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.shellstone.withValues(alpha: 0.58),
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final term in model.terms) _ThemeChip(term)],
            ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip(this.term);

  final String term;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppColors.quicksand.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.quicksand.withValues(alpha: 0.2)),
      ),
      child: Text(
        term,
        style: AppTextStyles.body(
          fontSize: 12,
          color: AppColors.swanWing.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}

class _CosmicPage extends StatelessWidget {
  const _CosmicPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SolenneBackground(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.55, -0.42),
                  radius: 1.2,
                  colors: [
                    AppColors.sapphire.withValues(alpha: 0.28),
                    AppColors.royalBlue.withValues(alpha: 0.78),
                    Colors.black.withValues(alpha: 0.94),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.tint = AppColors.royalBlue,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return SolenneGlass(
      padding: padding,
      borderRadius: 24,
      tint: tint,
      child: child,
    );
  }
}

class _SignalOrbPainter extends CustomPainter {
  const _SignalOrbPainter(this.valence, this.stress);

  final List<double> valence;
  final List<double> stress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final valenceAverage = _InsightModel._average(valence);
    final stressAverage = _InsightModel._average(stress);
    final cool = AppColors.sapphire.withValues(
      alpha: 0.42 + stressAverage * 0.24,
    );
    final warm = AppColors.quicksand.withValues(
      alpha: 0.3 + valenceAverage * 0.28,
    );
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [warm, cool, Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(
      center,
      radius * 0.74,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = AppColors.quicksand.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(covariant _SignalOrbPainter oldDelegate) =>
      oldDelegate.valence != valence || oldDelegate.stress != stress;
}

class _MiniTrendPainter extends CustomPainter {
  const _MiniTrendPainter({required this.points, required this.accent});

  final List<double> points;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final guide = Paint()
      ..color = AppColors.shellstone.withValues(alpha: 0.1)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height * 0.55),
      Offset(size.width, size.height * 0.55),
      guide,
    );
    if (points.length < 2) return;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * (i / (points.length - 1));
      final y = size.height - points[i].clamp(0.0, 1.0) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2.1
        ..color = accent.withValues(alpha: 0.72),
    );
  }

  @override
  bool shouldRepaint(covariant _MiniTrendPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.accent != accent;
}
