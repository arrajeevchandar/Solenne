import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'solenne_card.dart';

class SolenneLogoOrb extends StatefulWidget {
  const SolenneLogoOrb({super.key, this.size = 112, this.animate = true});

  final double size;
  final bool animate;

  @override
  State<SolenneLogoOrb> createState() => _SolenneLogoOrbState();
}

class _SolenneLogoOrbState extends State<SolenneLogoOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    );
    if (widget.animate) _controller.repeat();
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
      builder: (context, child) {
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _LogoOrbPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _LogoOrbPainter extends CustomPainter {
  const _LogoOrbPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.aqua.withValues(alpha: 0.30),
          AppColors.aqua.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, glow);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = AppColors.aqua.withValues(alpha: 0.22);
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * (i / 4), ring);
    }

    final sweep = Paint()
      ..shader = SweepGradient(
        startAngle: progress * math.pi * 2,
        endAngle: progress * math.pi * 2 + math.pi * 2,
        colors: const [
          AppColors.aqua,
          AppColors.violet,
          AppColors.coral,
          AppColors.aqua,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.38));
    canvas.drawCircle(center, radius * 0.33, sweep);

    final core = Paint()..color = AppColors.aqua.withValues(alpha: 0.86);
    canvas.drawCircle(center, radius * 0.24, core);

    final star = Path();
    const points = 5;
    for (var i = 0; i < points * 2; i++) {
      final angle = -math.pi / 2 + i * math.pi / points;
      final r = i.isEven ? radius * 0.12 : radius * 0.055;
      final p = Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
      if (i == 0) {
        star.moveTo(p.dx, p.dy);
      } else {
        star.lineTo(p.dx, p.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = AppColors.textPrimary);
  }

  @override
  bool shouldRepaint(covariant _LogoOrbPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class SolenneSectionTitle extends StatelessWidget {
  const SolenneSectionTitle({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String? eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    color: AppColors.aqua,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class SolenneMetricTile extends StatelessWidget {
  const SolenneMetricTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SolenneCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class SolenneStatusChip extends StatelessWidget {
  const SolenneStatusChip({
    super.key,
    required this.label,
    this.color = AppColors.aqua,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class SolenneActivityBars extends StatelessWidget {
  const SolenneActivityBars({
    super.key,
    this.values = const [2, 3, 1, 4, 3, 0, 1],
  });

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final maxValue = values.isEmpty ? 1 : values.reduce(math.max).clamp(1, 9);
    return SizedBox(
      height: 128,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          final value = index < values.length ? values[index] : 0;
          final height = 18 + (value / maxValue) * 76;
          final color = index == 4 ? AppColors.aqua : AppColors.violet;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [color, color.withValues(alpha: 0.42)],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    labels[index],
                    style: GoogleFonts.dmMono(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class SolenneVideoTile extends StatelessWidget {
  const SolenneVideoTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
    this.thumbnailUrl,
    this.onTap,
    this.chips = const [],
  });

  final String title;
  final String subtitle;
  final String? thumbnailUrl;
  final Color color;
  final VoidCallback? onTap;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: SolenneCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.84),
                      color.withValues(alpha: 0.24),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  image: thumbnailUrl == null || thumbnailUrl!.isEmpty
                      ? null
                      : DecorationImage(
                          image: NetworkImage(thumbnailUrl!),
                          fit: BoxFit.cover,
                        ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.aqua,
                  size: 34,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmMono(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 7, runSpacing: 6, children: chips),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
