import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../routing/fade_through_route.dart';
import 'walkthrough_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _skyController;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _screenFade;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );

    _skyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );

    _logoScale = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.1, 0.72, curve: Curves.easeOutCubic),
      ),
    );

    _screenFade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.82, 1.0, curve: Curves.easeIn),
      ),
    );

    _fadeController.forward().then((_) {
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(fadeThroughRoute(const WalkthroughScreen()));
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _skyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _fadeController,
        builder: (context, _) {
          final logoWidth = math.min(
            MediaQuery.of(context).size.width * 0.7,
            310.0,
          );

          return FadeTransition(
            opacity: _screenFade,
            child: SizedBox.expand(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF050914),
                      Color(0xFF0A1628),
                      AppColors.royalBlue,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _skyController,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _StarlitSkyPainter(
                              progress: _skyController.value,
                            ),
                          );
                        },
                      ),
                    ),
                    Center(
                      child: FadeTransition(
                        opacity: _logoFade,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: logoWidth * 1.34,
                                height: logoWidth * 1.34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      AppColors.quicksand.withValues(
                                        alpha: 0.15,
                                      ),
                                      AppColors.sapphire.withValues(
                                        alpha: 0.12,
                                      ),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.45, 1.0],
                                  ),
                                ),
                              ),
                              Container(
                                width: logoWidth * 1.02,
                                height: logoWidth * 1.02,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      AppColors.sapphire.withValues(
                                        alpha: 0.18,
                                      ),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              Image.asset(
                                'assets/images/logo.png',
                                width: logoWidth,
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StarlitSkyPainter extends CustomPainter {
  final double progress;

  const _StarlitSkyPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(77);

    // Very subtle tiny stars (reduced number + smaller size)
    for (int i = 0; i < 140; i++) {
      // Reduced from 230
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 0.25 + random.nextDouble() * 0.7; // Much smaller

      final phase = random.nextDouble() * math.pi * 2;
      final twinkle = 0.6 + 0.4 * math.sin(progress * math.pi * 2 + phase);

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = Colors.white.withValues(alpha: 0.35 + twinkle * 0.45),
      );
    }

    // Even fewer bigger stars
    for (int i = 0; i < 18; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height * 0.75;
      final phase = random.nextDouble() * math.pi * 2;
      final glow = 0.4 + 0.6 * math.sin(progress * math.pi * 2.4 + phase);

      final point = Offset(x, y);

      canvas.drawCircle(
        point,
        1.1,
        Paint()
          ..color = AppColors.swanWing.withValues(alpha: 0.55 + glow * 0.35),
      );
    }

    // Very subtle shooting stars (smaller & less visible)
    final shootingStars = [
      _ShootingStar(
        start: Offset(size.width * -0.2, size.height * 0.22),
        distance: size.width * 0.55,
        delay: 0.05,
        span: 0.22,
      ),
      _ShootingStar(
        start: Offset(size.width * 0.45, size.height * 0.08),
        distance: size.width * 0.48,
        delay: 0.45,
        span: 0.19,
      ),
      _ShootingStar(
        start: Offset(size.width * -0.12, size.height * 0.55),
        distance: size.width * 0.52,
        delay: 0.72,
        span: 0.20,
      ),
    ];

    for (final star in shootingStars) {
      _paintShootingStar(canvas, star);
    }
  }

  void _paintShootingStar(Canvas canvas, _ShootingStar star) {
    var localT = (progress - star.delay) / star.span;
    localT = localT - localT.floorToDouble();

    final fadeIn = Curves.easeOut.transform((localT / 0.18).clamp(0.0, 1.0));
    final fadeOut = Curves.easeIn.transform(
      ((1 - localT) / 0.25).clamp(0.0, 1.0),
    );
    final opacity = fadeIn * fadeOut * 0.75; // Reduced overall visibility

    if (opacity <= 0.03) return;

    final eased = Curves.easeOutCubic.transform(localT);
    final direction = Offset(0.9, 0.45);
    final head = star.start + direction * star.distance * eased;
    final tail = head - direction * 55; // Shorter tail

    final tailPaint = Paint()
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          AppColors.quicksand.withValues(alpha: 0.25 * opacity),
          AppColors.swanWing.withValues(alpha: 0.65 * opacity),
        ],
      ).createShader(Rect.fromPoints(tail, head));

    canvas.drawLine(tail, head, tailPaint);

    // Tiny head
    canvas.drawCircle(
      head,
      1.1,
      Paint()..color = AppColors.swanWing.withValues(alpha: 0.85 * opacity),
    );
  }

  @override
  bool shouldRepaint(_StarlitSkyPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ShootingStar {
  final Offset start;
  final double distance;
  final double delay;
  final double span;

  const _ShootingStar({
    required this.start,
    required this.distance,
    required this.delay,
    required this.span,
  });
}
