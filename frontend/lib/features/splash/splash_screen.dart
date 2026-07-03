import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/organic_background.dart';
import '../../core/widgets/solenne_visuals.dart';

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
              const SolenneOrb(size: 118),
              const SizedBox(height: 28),
              Text(
                'Solenne',
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontSize: 44),
              ),
              const SizedBox(height: 8),
              Text(
                'private video reflections',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.quicksand),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
