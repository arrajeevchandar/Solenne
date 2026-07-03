import 'package:flutter/material.dart';

import 'screens/app_shell.dart';
import 'screens/onboarding/splash_screen.dart';
import 'theme/app_theme.dart';

class SolenneApp extends StatelessWidget {
  const SolenneApp({super.key, required this.isAuthenticated});

  final bool isAuthenticated;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solenne',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: isAuthenticated ? const AppShell() : const SplashScreen(),
    );
  }
}
