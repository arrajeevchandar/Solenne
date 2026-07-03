import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SolenneButton extends StatelessWidget {
  const SolenneButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isSecondary = false,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isSecondary;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final foreground = isSecondary
        ? AppColors.textPrimary
        : AppColors.royalBlue;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon ?? Icons.arrow_forward_rounded),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: isSecondary
              ? AppColors.sapphire.withValues(alpha: 0.38)
              : AppColors.quicksand,
          foregroundColor: foreground,
          disabledBackgroundColor: AppColors.sapphire.withValues(alpha: 0.32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: isSecondary
                  ? AppColors.swanWing.withValues(alpha: 0.14)
                  : Colors.transparent,
            ),
          ),
          textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
