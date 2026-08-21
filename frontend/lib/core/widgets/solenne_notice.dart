import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class SolenneNotice {
  SolenneNotice._();

  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.check_rounded,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.quicksand.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppColors.quicksand.withValues(alpha: 0.48),
                  ),
                ),
                child: Icon(icon, size: 17, color: AppColors.quicksand),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(message, style: AppTextStyles.body(fontSize: 12)),
              ),
            ],
          ),
        ),
      );
  }
}
