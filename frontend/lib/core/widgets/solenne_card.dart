import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SolenneCard extends StatelessWidget {
  const SolenneCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ivoryWhite.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepCharcoal.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          const BoxShadow(
            color: Colors.white70,
            blurRadius: 8,
            offset: Offset(-3, -3),
          ),
        ],
      ),
      child: child,
    );
  }
}
