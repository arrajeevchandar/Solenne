import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class OrganicBackground extends StatelessWidget {
  const OrganicBackground({
    super.key,
    required this.child,
    this.showGrid = true,
  });

  final Widget child;
  final bool showGrid;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: AppColors.midnight)),
        Positioned.fill(child: CustomPaint(painter: _CosmicPainter(showGrid))),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _CosmicPainter extends CustomPainter {
  const _CosmicPainter(this.showGrid);

  final bool showGrid;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.midnight, AppColors.royalBlue, Color(0xFF060A1F)],
      ).createShader(rect);
    canvas.drawRect(rect, base);

    void glow(Offset center, double radius, Color color, double alpha) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    glow(
      Offset(size.width * 0.08, size.height * 0.12),
      size.width * 0.62,
      AppColors.sapphire,
      0.36,
    );
    glow(
      Offset(size.width * 0.92, size.height * 0.18),
      size.width * 0.54,
      AppColors.violet,
      0.18,
    );
    glow(
      Offset(size.width * 0.15, size.height * 0.88),
      size.width * 0.58,
      AppColors.quicksand,
      0.16,
    );

    if (showGrid) {
      final grid = Paint()
        ..color = AppColors.swanWing.withValues(alpha: 0.035)
        ..strokeWidth = 1;
      const step = 32.0;
      for (double x = 0; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      }
      for (double y = 0; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      }
    }

    final orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = AppColors.shellstone.withValues(alpha: 0.10);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.70, size.height * 0.28),
        width: size.width * 0.82,
        height: size.width * 0.34,
      ),
      orbit,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.30, size.height * 0.72),
        width: size.width * 0.92,
        height: size.width * 0.28,
      ),
      orbit,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
