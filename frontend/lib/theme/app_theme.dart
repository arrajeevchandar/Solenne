import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // Core palette — Sapphire / Royal Blue / Quicksand / Swan Wing / Shellstone
  static const Color sapphire = Color(0xFF3C507D);
  static const Color royalBlue = Color(0xFF112250);
  static const Color quicksand = Color(0xFFE0C68F);
  static const Color electricGold = Color(0xFFFFD86B);
  static const Color swanWing = Color(0xFFF5F0E9);
  static const Color shellstone = Color(0xFFD8CBC2);

  // Semantic mapping
  static const Color background = royalBlue;
  static const Color surface = sapphire;
  static const Color textPrimary = swanWing;
  static const Color textSecondary = shellstone;
  static const Color accentWarm = quicksand;
  static const Color accentCool = sapphire;
  static const Color nudgeWarm = Color(0xFF997953);
}

class AppDurations {
  AppDurations._();
  static const Duration transition = Duration(milliseconds: 400);
  static const Duration transitionSlow = Duration(milliseconds: 600);
}

class AppTextStyles {
  AppTextStyles._();

  static TextStyle display({double fontSize = 48, Color? color}) {
    return GoogleFonts.cormorantGaramond(
      fontSize: fontSize,
      fontWeight: FontWeight.w300,
      color: color ?? AppColors.textPrimary,
      letterSpacing: 0.5,
      height: 1.2,
    );
  }

  static TextStyle body({
    double fontSize = 16,
    Color? color,
    FontStyle? fontStyle,
  }) {
    return GoogleFonts.lora(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      fontStyle: fontStyle ?? FontStyle.normal,
      color: color ?? AppColors.textPrimary,
      height: 1.6,
    );
  }

  static TextStyle mono({double fontSize = 12, Color? color}) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      color: color ?? AppColors.textSecondary,
      letterSpacing: 1.4,
    );
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.accentWarm,
        secondary: AppColors.accentCool,
      ),
    );
  }
}

class FadeThroughPageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeThroughPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
      child: child,
    );
  }
}

class SolenneBackground extends StatelessWidget {
  const SolenneBackground({
    super.key,
    required this.child,
    this.showGrain = true,
  });

  final Widget child;
  final bool showGrain;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _SolenneBackgroundPainter(showGrain)),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class SolenneGlass extends StatelessWidget {
  const SolenneGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 24,
    this.width = double.infinity,
    this.height,
    this.tint,
    this.blur = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double? width;
  final double? height;
  final Color? tint;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: AppColors.swanWing.withValues(alpha: 0.18),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.swanWing.withValues(alpha: 0.09),
                (tint ?? AppColors.sapphire).withValues(alpha: 0.22),
                AppColors.royalBlue.withValues(alpha: 0.18),
                Colors.black.withValues(alpha: 0.08),
              ],
              stops: const [0, 0.34, 0.72, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: AppColors.sapphire.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(-8, -10),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _SolenneBackgroundPainter extends CustomPainter {
  const _SolenneBackgroundPainter(this.showGrain);

  final bool showGrain;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF08122A), Color(0xFF0D1F46), Color(0xFF050A1D)],
          stops: [0, 0.48, 1],
        ).createShader(rect),
    );

    void drawGlow({
      required Offset center,
      required double radius,
      required List<Color> colors,
    }) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: colors,
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    drawGlow(
      center: Offset(size.width * 0.5, size.height * 1.02),
      radius: size.width * 0.84,
      colors: [
        AppColors.sapphire.withValues(alpha: 0.34),
        AppColors.royalBlue.withValues(alpha: 0.28),
        Colors.transparent,
      ],
    );
    drawGlow(
      center: Offset(size.width * 0.78, size.height * 0.16),
      radius: size.width * 0.56,
      colors: [AppColors.sapphire.withValues(alpha: 0.2), Colors.transparent],
    );
    drawGlow(
      center: Offset(size.width * 0.05, size.height * 0.52),
      radius: size.width * 0.46,
      colors: [AppColors.royalBlue.withValues(alpha: 0.32), Colors.transparent],
    );

    final bottomLift = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          AppColors.sapphire.withValues(alpha: 0.0),
          AppColors.sapphire.withValues(alpha: 0.36),
          AppColors.royalBlue.withValues(alpha: 0.2),
        ],
        stops: const [0, 0.52, 0.82, 1],
      ).createShader(rect);
    canvas.drawRect(rect, bottomLift);

    final innerShadow = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.98,
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.38)],
        stops: const [0.58, 1],
      ).createShader(rect);
    canvas.drawRect(rect, innerShadow);

    if (!showGrain) return;

    final random = math.Random(41);
    for (int i = 0; i < 190; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        0.24 + random.nextDouble() * 0.62,
        Paint()
          ..color = AppColors.shellstone.withValues(
            alpha: 0.09 + random.nextDouble() * 0.14,
          ),
      );
    }

    for (int i = 0; i < 42; i++) {
      final point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height * 0.78,
      );
      final radius = 0.95 + random.nextDouble() * 0.75;
      canvas.drawCircle(
        point,
        radius,
        Paint()
          ..color = AppColors.swanWing.withValues(
            alpha: 0.38 + random.nextDouble() * 0.36,
          ),
      );
      canvas.drawCircle(
        point,
        radius * 3.6,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.sapphire.withValues(alpha: 0.2),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: point, radius: radius * 4)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SolenneBackgroundPainter oldDelegate) =>
      oldDelegate.showGrain != showGrain;
}
