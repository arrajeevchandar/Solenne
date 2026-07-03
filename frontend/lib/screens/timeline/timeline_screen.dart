import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  int _expandedIndex = 0;

  final _days = const [
    _TimelineDay(
      date: '13 June',
      hasEntry: true,
      length: 0.86,
      tint: AppColors.quicksand,
      observation: 'You sounded more settled by the end than at the start.',
      tags: ['sleep', 'work', 'uncertainty'],
    ),
    _TimelineDay(
      date: '12 June',
      hasEntry: true,
      length: 0.72,
      tint: AppColors.shellstone,
      observation: 'A small good thing kept returning in the background.',
      tags: ['family', 'rest', 'something good'],
    ),
    _TimelineDay(
      date: '11 June',
      hasEntry: true,
      length: 0.94,
      tint: AppColors.sapphire,
      observation: 'There was more future-tense language than usual.',
      tags: ['plans', 'work', 'change'],
    ),
    _TimelineDay(
      date: '10 June',
      hasEntry: false,
      length: 0.36,
      tint: AppColors.shellstone,
      observation: '',
      tags: [],
    ),
    _TimelineDay(
      date: '9 June',
      hasEntry: true,
      length: 0.42,
      tint: AppColors.quicksand,
      observation: 'Your voice got quieter when you talked about timing.',
      tags: ['sleep', 'timing', 'pressure'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _CosmicPage(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 106),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Timeline', style: AppTextStyles.display(fontSize: 36)),
              const SizedBox(height: 4),
              Text(
                'Look back without turning it into a report.',
                style: AppTextStyles.body(
                  fontSize: 14,
                  color: AppColors.shellstone.withValues(alpha: 0.72),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 26),
              _ZoomHint(),
              const SizedBox(height: 18),
              for (int i = 0; i < _days.length; i++) ...[
                _TimelineRow(
                  day: _days[i],
                  expanded: _expandedIndex == i && _days[i].hasEntry,
                  onTap: () => setState(() => _expandedIndex = i),
                ),
                const SizedBox(height: 14),
              ],
              const SizedBox(height: 10),
              _MonthPatternPreview(days: _days),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final _TimelineDay day;
  final bool expanded;
  final VoidCallback onTap;

  const _TimelineRow({
    required this.day,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: day.hasEntry ? onTap : null,
      child: AnimatedContainer(
        duration: AppDurations.transition,
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(14, 12, 14, expanded ? 16 : 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: expanded
                ? day.tint.withValues(alpha: 0.36)
                : AppColors.shellstone.withValues(alpha: 0.14),
          ),
          color: AppColors.royalBlue.withValues(alpha: expanded ? 0.28 : 0.14),
        ),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 78,
                  child: Text(
                    day.date,
                    style: AppTextStyles.mono(
                      fontSize: 11,
                      color: AppColors.shellstone.withValues(alpha: 0.78),
                    ),
                  ),
                ),
                Icon(
                  day.hasEntry ? Icons.circle : Icons.circle_outlined,
                  size: 13,
                  color: day.hasEntry
                      ? day.tint.withValues(alpha: 0.92)
                      : AppColors.shellstone.withValues(alpha: 0.52),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 20,
                    child: CustomPaint(
                      painter: _FingerprintLinePainter(
                        length: day.length,
                        color: day.hasEntry ? day.tint : AppColors.shellstone,
                        hasEntry: day.hasEntry,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 16),
              _ExpandedDay(day: day),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpandedDay extends StatelessWidget {
  final _TimelineDay day;

  const _ExpandedDay({required this.day});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 76,
          height: 86,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: RadialGradient(
              center: const Alignment(-0.4, -0.5),
              colors: [
                day.tint.withValues(alpha: 0.44),
                AppColors.sapphire.withValues(alpha: 0.22),
                AppColors.royalBlue.withValues(alpha: 0.1),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                day.observation,
                style: AppTextStyles.body(
                  fontSize: 14,
                  color: AppColors.swanWing.withValues(alpha: 0.9),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: day.tags.map((tag) => _Tag(label: tag)).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.headphones_rounded,
                    size: 16,
                    color: AppColors.quicksand.withValues(alpha: 0.76),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Listen back',
                    style: AppTextStyles.mono(
                      fontSize: 10,
                      color: AppColors.quicksand.withValues(alpha: 0.76),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;

  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.quicksand.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.quicksand.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: AppTextStyles.mono(
          fontSize: 9,
          color: AppColors.shellstone.withValues(alpha: 0.76),
        ),
      ),
    );
  }
}

class _ZoomHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Row(
        children: [
          Icon(
            Icons.pinch_rounded,
            size: 17,
            color: AppColors.quicksand.withValues(alpha: 0.72),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pinch out to see weeks and months as patterns.',
              style: AppTextStyles.body(
                fontSize: 13,
                color: AppColors.shellstone.withValues(alpha: 0.72),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthPatternPreview extends StatelessWidget {
  final List<_TimelineDay> days;

  const _MonthPatternPreview({required this.days});

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Month view',
            style: AppTextStyles.body(
              fontSize: 17,
              color: AppColors.swanWing.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(28, (index) {
              final active = index % 5 != 2;
              final color = Color.lerp(
                AppColors.sapphire,
                AppColors.quicksand,
                (index % 7) / 7,
              )!;
              return Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? color.withValues(alpha: 0.72)
                      : Colors.transparent,
                  border: active
                      ? null
                      : Border.all(
                          color: AppColors.shellstone.withValues(alpha: 0.32),
                        ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _FingerprintLinePainter extends CustomPainter {
  final double length;
  final Color color;
  final bool hasEntry;

  const _FingerprintLinePainter({
    required this.length,
    required this.color,
    required this.hasEntry,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final endX = size.width * (hasEntry ? length : 0.22);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = hasEntry
          ? color.withValues(alpha: 0.72)
          : AppColors.shellstone.withValues(alpha: 0.34);
    canvas.drawLine(
      Offset.zero.translate(0, size.height / 2),
      Offset(endX, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_FingerprintLinePainter oldDelegate) =>
      oldDelegate.length != length ||
      oldDelegate.color != color ||
      oldDelegate.hasEntry != hasEntry;
}

class _TimelineDay {
  final String date;
  final bool hasEntry;
  final double length;
  final Color tint;
  final String observation;
  final List<String> tags;

  const _TimelineDay({
    required this.date,
    required this.hasEntry,
    required this.length,
    required this.tint,
    required this.observation,
    required this.tags,
  });
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
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.shellstone.withValues(alpha: 0.18),
            ),
            color: AppColors.royalBlue.withValues(alpha: 0.2),
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
    final random = math.Random(17);
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
