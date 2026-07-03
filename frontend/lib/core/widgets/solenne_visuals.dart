import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class SolenneOrb extends StatefulWidget {
  const SolenneOrb({super.key, this.size = 92});

  final double size;

  @override
  State<SolenneOrb> createState() => _SolenneOrbState();
}

class _SolenneOrbState extends State<SolenneOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _OrbPainter(_controller.value),
        );
      },
    );
  }
}

class _OrbPainter extends CustomPainter {
  const _OrbPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.quicksand.withValues(alpha: 0.36),
          AppColors.sapphire.withValues(alpha: 0.14),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.2));
    canvas.drawCircle(center, radius * 1.2, glow);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..shader = SweepGradient(
        transform: GradientRotation(progress * math.pi * 2),
        colors: const [
          AppColors.quicksand,
          AppColors.swanWing,
          AppColors.sapphire,
          AppColors.violet,
          AppColors.quicksand,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius * 0.78, ring);

    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.swanWing, AppColors.shellstone, AppColors.quicksand],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.54));
    canvas.drawCircle(center, radius * 0.52, fill);

    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.royalBlue.withValues(alpha: 0.72);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.30),
      -math.pi * 0.15,
      math.pi * 1.20,
      false,
      inner,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: AppTextStyles.monoLabel);
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.royalBlue.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.swanWing.withValues(alpha: 0.11)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.quicksand, size: 20),
            const SizedBox(height: 10),
          ],
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
