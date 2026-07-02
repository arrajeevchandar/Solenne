import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class OrganicBackground extends StatelessWidget {
  const OrganicBackground({
    super.key,
    required this.child,
    this.showGrid = false,
  });

  final Widget child;
  final bool showGrid;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: AppColors.midnight)),
        Positioned.fill(
          child: CustomPaint(
            painter: _SolenneAmbientPainter(showGrid: showGrid),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _SolenneAmbientPainter extends CustomPainter {
  const _SolenneAmbientPainter({required this.showGrid});

  final bool showGrid;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    void glow(Offset center, double radius, Color color, double alpha) {
      paint.shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
      paint.shader = null;
    }

    glow(
      Offset(size.width * 0.15, size.height * 0.20),
      size.width * 0.58,
      AppColors.aqua,
      0.16,
    );
    glow(
      Offset(size.width * 0.86, size.height * 0.06),
      size.width * 0.48,
      AppColors.violet,
      0.17,
    );
    glow(
      Offset(size.width * 0.96, size.height * 0.76),
      size.width * 0.50,
      AppColors.violet,
      0.13,
    );
    glow(
      Offset(size.width * 0.10, size.height * 0.90),
      size.width * 0.46,
      AppColors.coral,
      0.10,
    );

    if (showGrid) {
      final gridPaint = Paint()
        ..color = AppColors.gridLine
        ..strokeWidth = 0.6;
      const spacing = 42.0;
      for (double x = 0; x <= size.width; x += spacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = 0; y <= size.height; y += spacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
