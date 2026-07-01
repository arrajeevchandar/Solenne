import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/organic_background.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      final target = FirebaseAuth.instance.currentUser == null
          ? '/onboarding'
          : '/home';
      context.go(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrganicBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: AppColors.ivoryWhite,
                  borderRadius: BorderRadius.circular(34),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.self_improvement_rounded,
                  color: AppColors.aqua,
                  size: 54,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Solenne',
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(letterSpacing: 0.2),
              ),
              const SizedBox(height: 8),
              Text(
                'A softer daily reflection',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
