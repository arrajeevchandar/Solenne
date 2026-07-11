import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class InsightsScreen extends StatelessWidget {
  final VoidCallback onTalkAboutIt;

  const InsightsScreen({super.key, required this.onTalkAboutIt});

  @override
  Widget build(BuildContext context) {
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
                'A quieter way to notice your patterns.',
                style: AppTextStyles.body(
                  fontSize: 14,
                  color: AppColors.shellstone.withValues(alpha: 0.72),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 22),
              const _WeekSnapshot(),
              const SizedBox(height: 16),
              const _MetricGrid(),
              const SizedBox(height: 22),
              Text(
                'Patterns',
                style: AppTextStyles.body(
                  fontSize: 18,
                  color: AppColors.swanWing.withValues(alpha: 0.94),
                ),
              ),
              const SizedBox(height: 12),
              const _PatternsCarousel(),
              const SizedBox(height: 18),
              _GentleNudge(onTalkAboutIt: onTalkAboutIt),
              const SizedBox(height: 16),
              const _LanguageField(),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekSnapshot extends StatelessWidget {
  const _WeekSnapshot();

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
                'THIS WEEK',
                style: AppTextStyles.mono(
                  fontSize: 10,
                  color: AppColors.quicksand.withValues(alpha: 0.78),
                ),
              ),
              const Spacer(),
              Text(
                '7 days',
                style: AppTextStyles.mono(
                  fontSize: 10,
                  color: AppColors.shellstone.withValues(alpha: 0.54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'More settled',
                      style: AppTextStyles.display(fontSize: 30),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your overall rhythm',
                      style: AppTextStyles.body(
                        fontSize: 12,
                        color: AppColors.shellstone.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '68',
                style: AppTextStyles.display(
                  fontSize: 44,
                  color: AppColors.quicksand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const SizedBox(
            height: 66,
            child: CustomPaint(painter: _WeekPulsePainter()),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _DayLabel('S'),
              _DayLabel('M'),
              _DayLabel('T'),
              _DayLabel('W'),
              _DayLabel('T'),
              _DayLabel('F'),
              _DayLabel('S'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.mono(
        fontSize: 9,
        color: AppColors.shellstone.withValues(alpha: 0.5),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: const [
            _MetricCard(
              icon: Icons.graphic_eq_rounded,
              label: 'VOICE ENERGY',
              value: 'Steady',
              detail: 'Up 12%',
              points: [0.38, 0.54, 0.46, 0.64, 0.6],
            ),
            _MetricCard(
              icon: Icons.nights_stay_outlined,
              label: 'REST',
              value: '6.8h',
              detail: '3 mentions',
              points: [0.7, 0.58, 0.5, 0.42, 0.56],
            ),
            _MetricCard(
              icon: Icons.explore_outlined,
              label: 'OUTLOOK',
              value: 'Forward',
              detail: '42% future',
              points: [0.34, 0.38, 0.52, 0.7, 0.76],
            ),
            _MetricCard(
              icon: Icons.mic_none_rounded,
              label: 'CHECK-INS',
              value: '4 / 7',
              detail: 'This week',
              points: [0.3, 0.7, 0.32, 0.72, 0.72],
            ),
          ].map((card) => SizedBox(width: itemWidth, child: card)).toList(),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.points,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final List<double> points;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: SizedBox(
        height: 124,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 17,
              color: AppColors.quicksand.withValues(alpha: 0.74),
            ),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.display(fontSize: 27),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.mono(
                fontSize: 8,
                color: AppColors.shellstone.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 18,
              child: CustomPaint(painter: _MiniTrendPainter(points: points)),
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              style: AppTextStyles.body(
                fontSize: 10,
                color: AppColors.quicksand.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatternsCarousel extends StatelessWidget {
  const _PatternsCarousel();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 184,
      child: PageView(
        controller: PageController(viewportFraction: 0.84),
        padEnds: false,
        children: const [
          _PatternCard(
            label: 'ENERGY + WORK',
            value: '28%',
            direction: 'lower',
            caption: 'On work-heavy days',
            points: [0.74, 0.66, 0.7, 0.42, 0.38, 0.44],
          ),
          _PatternCard(
            label: 'LANGUAGE',
            value: '42%',
            direction: 'future-facing',
            caption: 'More than your usual',
            points: [0.24, 0.34, 0.39, 0.56, 0.68, 0.76],
          ),
          _PatternCard(
            label: 'CONNECTION',
            value: '11d',
            direction: 'since mentioned',
            caption: 'Your sister',
            points: [0.7, 0.66, 0.52, 0.4, 0.27, 0.18],
          ),
        ],
      ),
    );
  }
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({
    required this.label,
    required this.value,
    required this.direction,
    required this.caption,
    required this.points,
  });

  final String label;
  final String value;
  final String direction;
  final String caption;
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
              label,
              style: AppTextStyles.mono(
                fontSize: 9,
                color: AppColors.quicksand.withValues(alpha: 0.76),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: AppTextStyles.display(fontSize: 42)),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    direction,
                    style: AppTextStyles.body(
                      fontSize: 12,
                      color: AppColors.shellstone.withValues(alpha: 0.68),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              height: 44,
              child: CustomPaint(
                painter: _MiniTrendPainter(points: points, prominent: true),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              caption,
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.swanWing.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GentleNudge extends StatelessWidget {
  final VoidCallback onTalkAboutIt;

  const _GentleNudge({required this.onTalkAboutIt});

  @override
  Widget build(BuildContext context) {
    return _Glass(
      tint: AppColors.sapphire,
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
                Text(
                  'A softer stretch',
                  style: AppTextStyles.body(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '3 days felt quieter than usual',
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

class _LanguageField extends StatelessWidget {
  const _LanguageField();

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
          const SizedBox(height: 8),
          const SizedBox(
            height: 78,
            child: CustomPaint(painter: _LanguageFieldPainter()),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: const [
              _ThemeChip(label: 'sleep', strength: 0.94),
              _ThemeChip(label: 'work', strength: 0.76),
              _ThemeChip(label: 'change', strength: 0.58),
              _ThemeChip(label: 'rest', strength: 0.46),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({required this.label, required this.strength});

  final String label;
  final double strength;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppColors.sapphire.withValues(alpha: 0.16 + strength * 0.14),
        border: Border.all(
          color: AppColors.shellstone.withValues(alpha: 0.08 + strength * 0.15),
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.mono(
          fontSize: 9,
          color: AppColors.shellstone.withValues(alpha: 0.58 + strength * 0.25),
        ),
      ),
    );
  }
}

class _WeekPulsePainter extends CustomPainter {
  const _WeekPulsePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const values = [0.42, 0.5, 0.36, 0.58, 0.65, 0.6, 0.74];
    final points = _pointsFor(values, size, verticalPadding: 6);
    final fillPath = Path()
      ..moveTo(points.first.dx, size.height)
      ..lineTo(points.first.dx, points.first.dy);
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      linePath.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
      fillPath.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    fillPath
      ..lineTo(points.last.dx, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.sapphire.withValues(alpha: 0.46),
            Colors.transparent,
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..color = AppColors.quicksand.withValues(alpha: 0.88)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    for (final point in points) {
      canvas.drawCircle(point, 3, Paint()..color = AppColors.quicksand);
      canvas.drawCircle(point, 1.1, Paint()..color = AppColors.royalBlue);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniTrendPainter extends CustomPainter {
  const _MiniTrendPainter({required this.points, this.prominent = false});

  final List<double> points;
  final bool prominent;

  @override
  void paint(Canvas canvas, Size size) {
    final offsets = _pointsFor(
      points,
      size,
      verticalPadding: prominent ? 4 : 2,
    );
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (int i = 1; i < offsets.length; i++) {
      path.lineTo(offsets[i].dx, offsets[i].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.quicksand.withValues(alpha: prominent ? 0.88 : 0.7)
        ..strokeWidth = prominent ? 1.7 : 1.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (prominent) {
      for (final point in offsets) {
        canvas.drawCircle(point, 2.5, Paint()..color = AppColors.quicksand);
      }
    }
  }

  @override
  bool shouldRepaint(_MiniTrendPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.prominent != prominent;
}

List<Offset> _pointsFor(
  List<double> values,
  Size size, {
  required double verticalPadding,
}) {
  return List.generate(values.length, (index) {
    final x = index * size.width / (values.length - 1);
    final y =
        size.height -
        verticalPadding -
        values[index] * (size.height - verticalPadding * 2);
    return Offset(x, y);
  });
}

class _LanguageFieldPainter extends CustomPainter {
  const _LanguageFieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(21);
    for (int i = 0; i < 48; i++) {
      final x = random.nextDouble() * size.width;
      final y =
          size.height * (0.5 + math.sin(x / size.width * math.pi * 2) * 0.18) +
          random.nextDouble() * 22 -
          11;
      final radius = 1.5 + random.nextDouble() * 5.2;
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = Color.lerp(
            AppColors.sapphire,
            AppColors.quicksand,
            random.nextDouble(),
          )!.withValues(alpha: 0.18 + random.nextDouble() * 0.32),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CosmicPage extends StatelessWidget {
  final Widget child;

  const _CosmicPage({required this.child});

  @override
  Widget build(BuildContext context) => SolenneBackground(child: child);
}

class _Glass extends StatelessWidget {
  final Widget child;
  final Color? tint;
  final EdgeInsetsGeometry padding;

  const _Glass({
    required this.child,
    this.tint,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return SolenneGlass(
      padding: padding,
      borderRadius: 20,
      tint: tint,
      child: child,
    );
  }
}
