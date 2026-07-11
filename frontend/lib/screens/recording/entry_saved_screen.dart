import 'dart:async';
import 'package:flutter/material.dart';
import '../../routing/fade_through_route.dart';
import '../../theme/app_theme.dart';
import '../insights/daily_insight_screen.dart';

class EntrySavedScreen extends StatefulWidget {
  final String entryId;
  const EntrySavedScreen({super.key, required this.entryId});

  @override
  State<EntrySavedScreen> createState() => _EntrySavedScreenState();
}

class _EntrySavedScreenState extends State<EntrySavedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _animController.forward();

    _timer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          fadeThroughRoute(DailyInsightScreen(entryId: widget.entryId)),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SolenneBackground(
        child: Center(
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.sapphire.withValues(alpha: 0.2),
                          border: Border.all(
                            color: AppColors.quicksand.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 48,
                          color: AppColors.quicksand.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Entry saved.',
                        style: AppTextStyles.display(fontSize: 32),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Preparing your daily insights...',
                        style: AppTextStyles.body(
                          fontSize: 14,
                          color: AppColors.shellstone.withValues(alpha: 0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
