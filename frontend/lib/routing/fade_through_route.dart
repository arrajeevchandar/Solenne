import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Navigates with Solenne's signature "fade through black" transition.
/// Used instead of the default Material slide transition everywhere in the app.
Route<T> fadeThroughRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: AppDurations.transitionSlow,
    reverseTransitionDuration: AppDurations.transitionSlow,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Fade to black, then fade in the new screen — true "fade through black"
      return Stack(
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
              ),
            ),
            child: Container(color: Colors.black),
          ),
          FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
            ),
            child: child,
          ),
        ],
      );
    },
  );
}

/// Keeps the splash art visible while the first onboarding screen blooms in.
Route<T> splashRevealRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    opaque: false,
    transitionDuration: const Duration(milliseconds: 950),
    reverseTransitionDuration: AppDurations.transitionSlow,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final reveal = Curves.easeInOutCubic.transform(animation.value);
          final fade = Curves.easeOut.transform(
            ((animation.value - 0.16) / 0.84).clamp(0.0, 1.0),
          );
          final glow = math.sin(animation.value * math.pi);

          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.sapphire.withValues(alpha: 0.08 * glow),
                  ),
                ),
              ),
              ClipPath(
                clipper: _CircularRevealClipper(progress: reveal),
                child: Opacity(
                  opacity: fade,
                  child: Transform.scale(
                    scale: 1.04 - (0.04 * reveal),
                    child: child,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _CircularRevealClipper extends CustomClipper<Path> {
  const _CircularRevealClipper({required this.progress});

  final double progress;

  @override
  Path getClip(Size size) {
    final radius =
        math.sqrt(size.width * size.width + size.height * size.height) *
        progress.clamp(0.0, 1.0);
    return Path()..addOval(
      Rect.fromCircle(
        center: Offset(size.width * 0.5, size.height * 0.5),
        radius: math.max(1, radius),
      ),
    );
  }

  @override
  bool shouldReclip(covariant _CircularRevealClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}
