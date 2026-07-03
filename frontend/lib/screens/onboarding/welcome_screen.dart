import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../routing/fade_through_route.dart';
import 'intention_setting_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _begin() {
    Navigator.of(
      context,
    ).push(fadeThroughRoute(const IntentionSettingScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A1628), // deepest navy
                Color(0xFF112250), // royal blue
                Color(0xFF3C507D), // sapphire — warm lift at bottom
              ],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Stack(
                children: [
                  // Logo — dead center
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          width: 220,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'A record of who you are, over time.',
                          style: AppTextStyles.body(
                            fontSize: 15,
                            color: AppColors.shellstone.withValues(alpha: 0.7),
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Begin — pinned at bottom
                  Positioned(
                    bottom: 52,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: _begin,
                        child: Column(
                          children: [
                            Text(
                              'Begin',
                              style: AppTextStyles.mono(
                                fontSize: 13,
                                color: AppColors.quicksand.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Subtle gold underline hint
                            Container(
                              width: 20,
                              height: 1,
                              color: AppColors.quicksand.withValues(alpha: 0.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
