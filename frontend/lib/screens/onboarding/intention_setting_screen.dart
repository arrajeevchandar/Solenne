import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../routing/fade_through_route.dart';
import '../auth/auth_screen.dart';

enum Intention {
  understandMyself('I want to understand myself better'),
  goingThroughSomething('I\'ve been going through something difficult'),
  someoneSuggested('Someone suggested I try this'),
  notSure('I\'m not sure yet');

  final String label;
  const Intention(this.label);
}

/// Screen 2 — The Intention Setting
/// A single question. The answer shapes tone, not function.
class IntentionSettingScreen extends StatefulWidget {
  const IntentionSettingScreen({super.key});

  @override
  State<IntentionSettingScreen> createState() => _IntentionSettingScreenState();
}

class _IntentionSettingScreenState extends State<IntentionSettingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _skyController;
  Intention? _hovered;

  @override
  void initState() {
    super.initState();
    _skyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7200),
    )..repeat();
  }

  @override
  void dispose() {
    _skyController.dispose();
    super.dispose();
  }

  void _select(Intention intention) {
    // TODO: persist `intention` permanently — shapes AI tone for first two weeks.
    Navigator.of(context).push(fadeThroughRoute(const AuthScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final cardWidth = math.min(screenSize.width - 28, 382.0);
    final cardHeight = math.min(
      screenSize.height - 96,
      math.max(398.0, cardWidth * 1.18),
    );
    final compact = cardWidth < 350;

    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            const SolenneBackground(child: SizedBox.expand()),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _skyController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _CosmicQuestionPainter(
                      progress: _skyController.value,
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Center(
                child: SolenneGlass(
                  width: cardWidth,
                  height: cardHeight,
                  borderRadius: 22,
                  padding: EdgeInsets.fromLTRB(
                    compact ? 22 : 26,
                    compact ? 22 : 30,
                    compact ? 22 : 26,
                    compact ? 18 : 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 34,
                          height: 2,
                          decoration: BoxDecoration(
                            color: AppColors.quicksand.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 18 : 28),
                      Text(
                        'What brings you\nto Solenne?',
                        style: AppTextStyles.display(
                          fontSize: compact ? 28 : 32,
                        ),
                      ),
                      SizedBox(height: compact ? 18 : 28),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: Intention.values.map(_buildOption).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(Intention intention) {
    final isHovered = _hovered == intention;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = intention),
      onExit: (_) => setState(() => _hovered = null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _select(intention),
        child: AnimatedContainer(
          width: double.infinity,
          duration: AppDurations.transition,
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: MediaQuery.of(context).size.width < 370 ? 7 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isHovered
                  ? AppColors.quicksand.withValues(alpha: 0.58)
                  : AppColors.quicksand.withValues(alpha: 0.24),
            ),
            color: isHovered
                ? AppColors.quicksand.withValues(alpha: 0.13)
                : AppColors.quicksand.withValues(alpha: 0.055),
          ),
          child: Text(
            intention.label,
            style: AppTextStyles.body(
              fontSize: MediaQuery.of(context).size.width < 370 ? 14 : 15,
              color: isHovered
                  ? AppColors.textPrimary
                  : AppColors.textSecondary.withValues(alpha: 0.86),
            ),
          ),
        ),
      ),
    );
  }
}

class _CosmicQuestionPainter extends CustomPainter {
  final double progress;

  const _CosmicQuestionPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final lowerBlueGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.sapphire.withValues(alpha: 0.14),
              AppColors.royalBlue.withValues(alpha: 0.1),
              Colors.transparent,
            ],
            stops: const [0.0, 0.48, 1.0],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.72, size.height * 0.6),
              radius: size.shortestSide * 0.82,
            ),
          );
    canvas.drawRect(Offset.zero & size, lowerBlueGlow);

    final upperBlueGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.sapphire.withValues(alpha: 0.32),
              AppColors.royalBlue.withValues(alpha: 0.14),
              Colors.transparent,
            ],
            stops: const [0.0, 0.52, 1.0],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.28, size.height * 0.22),
              radius: size.shortestSide * 0.7,
            ),
          );
    canvas.drawRect(Offset.zero & size, upperBlueGlow);

    final random = math.Random(31);
    for (int i = 0; i < 180; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 0.22 + random.nextDouble() * 0.85;
      final phase = random.nextDouble() * math.pi * 2;
      final shimmer = 0.5 + 0.28 * math.sin(progress * math.pi * 2 + phase);
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = AppColors.shellstone.withValues(
            alpha: 0.12 + shimmer * 0.2,
          ),
      );
    }

    _paintParticleRibbon(canvas, size, seed: 101, brightness: 1, offset: 0);
    _paintParticleRibbon(
      canvas,
      size,
      seed: 203,
      brightness: 0.42,
      offset: -0.34,
    );
    _paintSparkles(canvas, size);
  }

  void _paintParticleRibbon(
    Canvas canvas,
    Size size, {
    required int seed,
    required double brightness,
    required double offset,
  }) {
    final random = math.Random(seed);
    final width = size.width;
    final height = size.height;

    for (int i = 0; i < 1250; i++) {
      final t = random.nextDouble();
      final wave = math.sin((t * 1.7 + offset) * math.pi * 2);
      final secondary = math.sin((t * 3.2 + 0.18 + offset) * math.pi * 2);
      final spineX =
          width * (0.58 + 0.28 * wave + 0.12 * secondary) - width * 0.08 * t;
      final spineY = height * (-0.08 + t * 1.2);
      final spread = math.pow(random.nextDouble(), 2.45) * width * 0.18;
      final side = random.nextBool() ? 1.0 : -1.0;
      final angle = -0.95 + wave * 0.45;
      final normal = Offset(math.cos(angle), math.sin(angle));
      final point = Offset(spineX, spineY) + normal * side * spread;
      if (point.dx < -20 ||
          point.dx > width + 20 ||
          point.dy < -20 ||
          point.dy > height + 20) {
        continue;
      }

      final core = 1 - (spread / (width * 0.18)).clamp(0.0, 1.0);
      final warmth = random.nextDouble();
      final color = Color.lerp(
        AppColors.shellstone,
        AppColors.quicksand,
        0.12 + warmth * 0.32,
      )!;
      canvas.drawCircle(
        point,
        0.2 + random.nextDouble() * (core > 0.66 ? 1.25 : 0.72),
        Paint()
          ..color = color.withValues(alpha: brightness * (0.08 + core * 0.62)),
      );
    }

    final dustPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.05
      ..strokeCap = StrokeCap.round
      ..color = AppColors.sapphire.withValues(alpha: 0.07 * brightness)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    final path = Path();
    for (int i = 0; i <= 80; i++) {
      final t = i / 80;
      final wave = math.sin((t * 1.7 + offset) * math.pi * 2);
      final secondary = math.sin((t * 3.2 + 0.18 + offset) * math.pi * 2);
      final x =
          width * (0.58 + 0.28 * wave + 0.12 * secondary) - width * 0.08 * t;
      final y = height * (-0.08 + t * 1.2);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, dustPaint);
  }

  void _paintSparkles(Canvas canvas, Size size) {
    final random = math.Random(404);
    for (int i = 0; i < 18; i++) {
      final t = random.nextDouble();
      final x =
          size.width *
          (0.18 + random.nextDouble() * 0.72 + 0.12 * math.sin(t * 9));
      final y = size.height * (0.08 + random.nextDouble() * 0.82);
      final center = Offset(x, y);
      final radius = 3.5 + random.nextDouble() * 5.5;
      final alpha = 0.26 + random.nextDouble() * 0.32;
      final paint = Paint()
        ..strokeWidth = 0.7
        ..strokeCap = StrokeCap.round
        ..color = AppColors.quicksand.withValues(alpha: alpha);
      canvas.drawLine(
        center.translate(-radius, 0),
        center.translate(radius, 0),
        paint,
      );
      canvas.drawLine(
        center.translate(0, -radius),
        center.translate(0, radius),
        paint,
      );
      canvas.drawCircle(
        center,
        1.1,
        Paint()..color = AppColors.shellstone.withValues(alpha: alpha + 0.12),
      );
    }
  }

  @override
  bool shouldRepaint(_CosmicQuestionPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
