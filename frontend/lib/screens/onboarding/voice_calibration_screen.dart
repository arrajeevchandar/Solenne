import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../routing/fade_through_route.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_screen.dart';

/// Screen 3 — The Voice Calibration
/// Removes performance anxiety around the first entry.
class VoiceCalibrationScreen extends StatefulWidget {
  const VoiceCalibrationScreen({super.key});

  @override
  State<VoiceCalibrationScreen> createState() => _VoiceCalibrationScreenState();
}

class _VoiceCalibrationScreenState extends State<VoiceCalibrationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _skyController;

  @override
  void initState() {
    super.initState();
    _skyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7600),
    )..repeat();
  }

  @override
  void dispose() {
    _skyController.dispose();
    super.dispose();
  }

  void _continueToAuth() {
    Navigator.of(context).pushReplacement(fadeThroughRoute(const AuthScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final cardWidth = math.min(screenSize.width - 30, 382.0);
    final cardHeight = math.min(
      screenSize.height - 172,
      math.max(350.0, cardWidth * 1.02),
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
                    painter: _RoyalCosmicPainter(
                      progress: _skyController.value,
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SolenneGlass(
                        width: cardWidth,
                        height: cardHeight,
                        borderRadius: 24,
                        padding: EdgeInsets.fromLTRB(
                          compact ? 24 : 28,
                          compact ? 26 : 32,
                          compact ? 24 : 28,
                          compact ? 24 : 30,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 34,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: AppColors.quicksand.withValues(
                                    alpha: 0.62,
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            SizedBox(height: compact ? 24 : 32),
                            Text(
                              'Solenne learns you\nspecifically.',
                              style: AppTextStyles.display(
                                fontSize: compact ? 30 : 34,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'This takes about two weeks of entries to build your personal baseline. Until then, it simply listens.',
                              style: AppTextStyles.body(
                                fontSize: compact ? 15 : 16,
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.88,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Your first entry can be about anything. There is no wrong entry.',
                              style: AppTextStyles.body(
                                fontSize: compact ? 13 : 14,
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.78,
                                ),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      _GoldenEntryButton(onTap: _continueToAuth),
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
}

class _GoldenEntryButton extends StatefulWidget {
  final VoidCallback onTap;

  const _GoldenEntryButton({required this.onTap});

  @override
  State<_GoldenEntryButton> createState() => _GoldenEntryButtonState();
}

class _GoldenEntryButtonState extends State<_GoldenEntryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _shimmer,
        builder: (context, _) {
          final glow = 0.55 + _shimmer.value * 0.3;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: AppColors.quicksand.withValues(alpha: glow),
              ),
              color: AppColors.quicksand.withValues(alpha: 0.1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.quicksand.withValues(alpha: 0.12),
                  blurRadius: 22,
                  spreadRadius: -3,
                ),
              ],
            ),
            child: Text(
              'Continue',
              style: AppTextStyles.mono(
                fontSize: 12,
                color: AppColors.quicksand.withValues(alpha: 0.86),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RoyalCosmicPainter extends CustomPainter {
  final double progress;

  const _RoyalCosmicPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final sapphireGlow = Paint()
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
              center: Offset(size.width * 0.24, size.height * 0.22),
              radius: size.shortestSide * 0.74,
            ),
          );
    canvas.drawRect(Offset.zero & size, sapphireGlow);

    final blueGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.sapphire.withValues(alpha: 0.14),
              AppColors.royalBlue.withValues(alpha: 0.1),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.74, size.height * 0.66),
              radius: size.shortestSide * 0.78,
            ),
          );
    canvas.drawRect(Offset.zero & size, blueGlow);

    final random = math.Random(311);
    for (int i = 0; i < 190; i++) {
      final phase = random.nextDouble() * math.pi * 2;
      final twinkle = 0.5 + 0.28 * math.sin(progress * math.pi * 2 + phase);
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        0.24 + random.nextDouble() * 0.9,
        Paint()
          ..color = AppColors.shellstone.withValues(
            alpha: 0.12 + twinkle * 0.22,
          ),
      );
    }

    _paintRibbon(canvas, size);
  }

  void _paintRibbon(Canvas canvas, Size size) {
    final random = math.Random(909);
    final width = size.width;
    final height = size.height;

    for (int i = 0; i < 980; i++) {
      final t = random.nextDouble();
      final wave = math.sin((t * 1.42 + 0.08) * math.pi * 2);
      final spineX = width * (0.55 + 0.26 * wave);
      final spineY = height * (-0.08 + t * 1.18);
      final spread = math.pow(random.nextDouble(), 2.5) * width * 0.16;
      final side = random.nextBool() ? 1.0 : -1.0;
      final normal = Offset(math.cos(-0.9 + wave * 0.4), math.sin(-0.9));
      final point = Offset(spineX, spineY) + normal * side * spread;
      if (point.dx < -20 ||
          point.dx > width + 20 ||
          point.dy < -20 ||
          point.dy > height + 20) {
        continue;
      }

      final core = 1 - (spread / (width * 0.16)).clamp(0.0, 1.0);
      final color = Color.lerp(
        AppColors.shellstone,
        AppColors.quicksand,
        0.16 + random.nextDouble() * 0.28,
      )!;
      canvas.drawCircle(
        point,
        0.22 + random.nextDouble() * (core > 0.65 ? 1.15 : 0.68),
        Paint()..color = color.withValues(alpha: 0.08 + core * 0.58),
      );
    }
  }

  @override
  bool shouldRepaint(_RoyalCosmicPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
