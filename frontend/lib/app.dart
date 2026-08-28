import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'screens/app_shell.dart';
import 'screens/onboarding/splash_screen.dart';
import 'theme/app_theme.dart';

class SolenneApp extends StatefulWidget {
  const SolenneApp({super.key, required this.isAuthenticated});

  final bool isAuthenticated;

  @override
  State<SolenneApp> createState() => _SolenneAppState();
}

class _SolenneAppState extends State<SolenneApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<User?>? _authSubscription;
  late bool _hadAuthenticatedSession;

  @override
  void initState() {
    super.initState();
    _hadAuthenticatedSession = widget.isAuthenticated;
    _authSubscription = FirebaseAuth.instance.userChanges().listen((user) {
      final wasAuthenticated = _hadAuthenticatedSession;
      _hadAuthenticatedSession = user != null;
      if (!wasAuthenticated || user != null) return;
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
        (_) => false,
      );
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Solenne',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: widget.isAuthenticated ? const AppShell() : const SplashScreen(),
    );
  }
}
