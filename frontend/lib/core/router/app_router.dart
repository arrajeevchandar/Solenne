import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/insights/insights_screen.dart';
import '../../features/journals/journal_detail_screen.dart';
import '../../features/journals/journal_list_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/recording/recording_draft.dart';
import '../../features/recording/recording_preview_screen.dart';
import '../../features/recording/recording_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/timeline/timeline_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  refreshListenable: GoRouterRefreshStream(
    FirebaseAuth.instance.authStateChanges(),
  ),
  redirect: (context, state) {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;
    final location = state.matchedLocation;
    final publicRoutes = {
      '/splash',
      '/onboarding',
      '/login',
      '/signup',
      '/forgot-password',
    };
    if (!isLoggedIn && !publicRoutes.contains(location)) return '/login';
    if (isLoggedIn && location == '/login') return '/home';
    if (isLoggedIn && location == '/signup') return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/journals',
          builder: (context, state) => const JournalListScreen(),
        ),
        GoRoute(
          path: '/timeline',
          builder: (context, state) => const TimelineScreen(),
        ),
        GoRoute(
          path: '/journals/:id',
          builder: (_, state) =>
              JournalDetailScreen(id: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/record',
          builder: (context, state) => const RecordingScreen(),
        ),
        GoRoute(
          path: '/insights',
          builder: (context, state) => const InsightsScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/record/preview',
      builder: (_, state) {
        final draft = state.extra as RecordingDraft;
        return RecordingPreviewScreen(draft: draft);
      },
    ),
  ],
);

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
