import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SolenneCard extends StatelessWidget {
  const SolenneCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.swanWing.withValues(alpha: 0.18),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.swanWing.withValues(alpha: 0.08),
                AppColors.sapphire.withValues(alpha: 0.24),
                AppColors.royalBlue.withValues(alpha: 0.18),
                Colors.black.withValues(alpha: 0.08),
              ],
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
          child: Padding(
            padding: padding ?? const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }
}
