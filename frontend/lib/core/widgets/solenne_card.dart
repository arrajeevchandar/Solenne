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
        color: AppColors.sapphire.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.swanWing.withValues(alpha: 0.13)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 34,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: AppColors.quicksand.withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(-8, -10),
          ),
        ],
      ),
      child: child,
    );
  }
}
