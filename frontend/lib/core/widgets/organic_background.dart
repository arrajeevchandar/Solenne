import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class OrganicBackground extends StatelessWidget {
  const OrganicBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: AppColors.creamBase)),
        Positioned.fill(child: CustomPaint(painter: _OrganicPainter())),
        child,
      ],
    );
  }
}

class _OrganicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = AppColors.pastelBlue.withValues(alpha: 0.45);
    final top = Path()
      ..moveTo(size.width * 0.35, 0)
      ..cubicTo(size.width * 0.7, size.height * 0.05, size.width * 0.9,
          size.height * 0.18, size.width, size.height * 0.08)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(top, paint);

    paint.color = AppColors.softSage.withValues(alpha: 0.38);
    final middle = Path()
      ..moveTo(0, size.height * 0.36)
      ..cubicTo(size.width * 0.22, size.height * 0.25, size.width * 0.42,
          size.height * 0.48, size.width * 0.68, size.height * 0.38)
      ..cubicTo(size.width * 0.86, size.height * 0.31, size.width * 0.95,
          size.height * 0.47, size.width, size.height * 0.42)
      ..lineTo(size.width, size.height * 0.62)
      ..cubicTo(size.width * 0.76, size.height * 0.68, size.width * 0.55,
          size.height * 0.56, 0, size.height * 0.72)
      ..close();
    canvas.drawPath(middle, paint);

    paint.color = AppColors.blushPink.withValues(alpha: 0.28);
    canvas.drawOval(
      Rect.fromCircle(
        center: Offset(size.width * 0.16, size.height * 0.86),
        radius: size.width * 0.28,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
