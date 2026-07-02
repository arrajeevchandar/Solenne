import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/organic_background.dart';
import '../../core/widgets/solenne_button.dart';
import '../../core/widgets/solenne_card.dart';
import '../../core/widgets/solenne_visuals.dart';
import '../auth/auth_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  String _goal = 'Build a daily reflection habit';

  static const _slides = [
    (
      Icons.wb_sunny_outlined,
      'Welcome to Solenne',
      'A calm place to record what today felt like and return to it when you need perspective.',
    ),
    (
      Icons.videocam_outlined,
      'Begin with your voice',
      'Capture a short video reflection. Your journals stay connected to your private account.',
    ),
    (
      Icons.lock_outline,
      'Privacy first',
      'For now Solenne stores your video journal and prepares it for future analysis only when you choose.',
    ),
  ];

  Future<void> _finish() async {
    if (FirebaseAuth.instance.currentUser == null) {
      context.go('/signup');
      return;
    }
    await ref
        .read(authRepositoryProvider)
        .completeOnboarding(wellnessGoal: _goal);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrganicBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (value) => setState(() => _page = value),
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 168,
                            height: 168,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.aqua.withValues(alpha: 0.22),
                                  blurRadius: 70,
                                ),
                              ],
                            ),
                            child: index == 0
                                ? const SolenneLogoOrb(size: 168)
                                : SolenneCard(
                                    padding: EdgeInsets.zero,
                                    child: Center(
                                      child: Icon(
                                        slide.$1,
                                        size: 72,
                                        color: AppColors.aqua,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            slide.$2,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 14),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 300),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                slide.$3,
                                textAlign: TextAlign.center,
                                softWrap: true,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.copyWith(fontSize: 15.5),
                              ),
                            ),
                          ),
                          if (index == 2) ...[
                            const SizedBox(height: 24),
                            DropdownButtonFormField<String>(
                              initialValue: _goal,
                              decoration: const InputDecoration(
                                labelText: 'Wellness goal',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Build a daily reflection habit',
                                  child: Text('Build a daily reflection habit'),
                                ),
                                DropdownMenuItem(
                                  value: 'Notice emotional patterns',
                                  child: Text('Notice emotional patterns'),
                                ),
                                DropdownMenuItem(
                                  value: 'Create a private video journal',
                                  child: Text('Create a private video journal'),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _goal = value ?? _goal),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(4),
                      width: _page == index ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _page == index
                            ? AppColors.aqua
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SolenneButton(
                  label: _page == _slides.length - 1
                      ? 'Start Reflecting'
                      : 'Continue',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () {
                    if (_page == _slides.length - 1) {
                      _finish();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                ),
                TextButton(
                  onPressed: () {
                    FirebaseAuth.instance.currentUser == null
                        ? context.go('/login')
                        : context.go('/home');
                  },
                  child: const Text('Skip for now'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
