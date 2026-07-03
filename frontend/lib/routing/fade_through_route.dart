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
