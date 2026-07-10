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
                "What Solenne has noticed across time.",
                style: AppTextStyles.body(
                  fontSize: 14,
                  color: AppColors.shellstone.withValues(alpha: 0.72),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 22),
              _GentleNudge(onTalkAboutIt: onTalkAboutIt),
              const SizedBox(height: 16),
              const _WeeklyReflection(),
              const SizedBox(height: 22),
              Text(
                'Patterns',
                style: AppTextStyles.body(
                  fontSize: 18,
                  color: AppColors.swanWing.withValues(alpha: 0.94),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 184,
                child: PageView(
                  controller: PageController(viewportFraction: 0.86),
                  padEnds: false,
                  children: const [
                    _PatternCard(
                      text:
                          'Your vocal energy is consistently lower on the days you mention work in the first 30 seconds.',
                      tint: AppColors.sapphire,
                    ),
                    _PatternCard(
                      text:
                          "Over the last three weeks, you've used future-tense language more than usual.",
                      tint: AppColors.sapphire,
                    ),
                    _PatternCard(
                      text:
                          "You haven't mentioned your sister in 11 days. Before that, she appeared almost daily.",
                      tint: AppColors.shellstone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const _LanguageField(),
            ],
          ),
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
      tint: AppColors.sapphire.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The last few days have felt heavier than your usual. No need to do anything — Solenne has noticed, and it is okay to say more if you want to.',
            style: AppTextStyles.body(
              fontSize: 15,
              color: AppColors.swanWing.withValues(alpha: 0.9),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onTalkAboutIt,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: AppColors.sapphire.withValues(alpha: 0.22),
                border: Border.all(
                  color: AppColors.shellstone.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                'Talk about it',
                style: AppTextStyles.mono(
                  fontSize: 10,
                  color: AppColors.quicksand.withValues(alpha: 0.86),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyReflection extends StatelessWidget {
  const _WeeklyReflection();

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This week',
            style: AppTextStyles.mono(
              fontSize: 10,
              color: AppColors.quicksand.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'This week had a different quality than last week — something in your voice was more settled, even on the days when the things you talked about were hard. You mentioned sleep three times, always briefly, like something you are noting but not ready to address yet. Thursday felt like a turning point of some kind.',
            style: AppTextStyles.body(
              fontSize: 15,
              color: AppColors.shellstone.withValues(alpha: 0.86),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternCard extends StatelessWidget {
  final String text;
  final Color tint;

  const _PatternCard({required this.text, required this.tint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SolenneGlass(
        padding: const EdgeInsets.all(20),
        borderRadius: 24,
        tint: tint,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: AppTextStyles.body(
              fontSize: 17,
              color: AppColors.swanWing.withValues(alpha: 0.9),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageField extends StatelessWidget {
  const _LanguageField();

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: SizedBox(
        height: 112,
        child: CustomPaint(painter: _LanguageFieldPainter()),
      ),
    );
  }
}

class _LanguageFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(21);
    for (int i = 0; i < 75; i++) {
      final t = random.nextDouble();
      final x = size.width * t;
      final y =
          size.height * (0.52 + math.sin(t * math.pi * 2.4) * 0.24) +
          random.nextDouble() * 16 -
          8;
      final radius = 1.5 + random.nextDouble() * 4.5;
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = Color.lerp(
            AppColors.sapphire,
            AppColors.quicksand,
            t,
          )!.withValues(alpha: 0.16 + random.nextDouble() * 0.3),
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
  Widget build(BuildContext context) {
    return SolenneBackground(child: child);
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  final Color? tint;

  const _Glass({required this.child, this.tint});

  @override
  Widget build(BuildContext context) {
    return SolenneGlass(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      tint: tint,
      child: child,
    );
  }
}
