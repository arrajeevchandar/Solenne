import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../routing/fade_through_route.dart';
import 'intention_setting_screen.dart';

class _SlideData {
  final String heading;
  final String subline;
  final double orbitalOffset;

  const _SlideData({
    required this.heading,
    required this.subline,
    required this.orbitalOffset,
  });
}

const _slides = [
  _SlideData(
    heading: 'A space\nthat listens.',
    subline: 'Not to judge. Not to fix.\nJust to hear you, over time.',
    orbitalOffset: 0.0,
  ),
  _SlideData(
    heading: 'Patterns,\nnot prescriptions.',
    subline: 'Solenne notices what you carry —\nquietly, without conclusions.',
    orbitalOffset: 0.3,
  ),
  _SlideData(
    heading: 'Yours,\nprivately, always.',
    subline: 'Everything stays with you.\nNo one else sees this.',
    orbitalOffset: 0.6,
  ),
];

class WalkthroughScreen extends StatefulWidget {
  const WalkthroughScreen({super.key});

  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _orbitalController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _orbitalController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _orbitalController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
  }

  void _goBack() {
    _pageController.previousPage(
      duration: AppDurations.transitionSlow,
      curve: Curves.easeInOut,
    );
  }

  void _skip() {
    Navigator.of(
      context,
    ).push(fadeThroughRoute(const IntentionSettingScreen()));
  }

  void _begin() {
    Navigator.of(
      context,
    ).push(fadeThroughRoute(const IntentionSettingScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;
    final isFirstSlide = _currentPage == 0;
    final isLastSlide = _currentPage == _slides.length - 1;

    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Deep navy base
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF080E1C),
                    Color(0xFF0F1E3F),
                    Color(0xFF0A1628),
                  ],
                ),
              ),
            ),

            // Orbital rings — centered at screen center
            AnimatedBuilder(
              animation: _orbitalController,
              builder: (context, _) {
                return CustomPaint(
                  size: size,
                  painter: _OrbitalPainter(
                    progress: _orbitalController.value,
                    slideOffset: _slides[_currentPage].orbitalOffset,
                  ),
                );
              },
            ),

            // Swipeable content
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _slides.length,
              itemBuilder: (context, index) {
                final isLast = index == _slides.length - 1;
                return _SlideContent(
                  slide: _slides[index],
                  isLast: isLast,
                  onBegin: _begin,
                );
              },
            ),

            // Back button — top left, hidden on first slide
            if (!isFirstSlide)
              Positioned(
                top: topPad + 16,
                left: 20,
                child: GestureDetector(
                  onTap: _goBack,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.arrow_back_ios_rounded,
                      size: 13,
                      color: AppColors.shellstone.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),

            // Skip — top right, hidden on last slide
            if (!isLastSlide)
              Positioned(
                top: topPad + 20,
                right: 28,
                child: GestureDetector(
                  onTap: _skip,
                  child: Text(
                    'skip',
                    style: AppTextStyles.mono(
                      fontSize: 11,
                      color: AppColors.shellstone.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),

            // Dots — bottom center
            Positioned(
              bottom: 52,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: AppDurations.transition,
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 28 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.quicksand
                          : AppColors.shellstone.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideContent extends StatelessWidget {
  final _SlideData slide;
  final bool isLast;
  final VoidCallback onBegin;

  const _SlideContent({
    required this.slide,
    required this.isLast,
    required this.onBegin,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(flex: 3),

            // Gold accent line
            Container(
              width: 28,
              height: 1.5,
              color: AppColors.quicksand.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 32),

            // Heading
            Text(
              slide.heading,
              style: AppTextStyles.display(fontSize: 40),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Subline
            Text(
              slide.subline,
              style: AppTextStyles.body(
                fontSize: 16,
                color: AppColors.shellstone.withValues(alpha: 0.75),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 48),

            // CTA on last slide — just clean text, no ornaments
            if (isLast) _WhimsicalButton(onTap: onBegin),

            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}

class _WhimsicalButton extends StatefulWidget {
  final VoidCallback onTap;
  const _WhimsicalButton({required this.onTap});

  @override
  State<_WhimsicalButton> createState() => _WhimsicalButtonState();
}

class _WhimsicalButtonState extends State<_WhimsicalButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _shimmer,
        builder: (context, _) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.quicksand.withValues(
                  alpha: 0.3 + 0.35 * _shimmer.value,
                ),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(2),
              color: AppColors.quicksand.withValues(
                alpha: 0.03 + 0.05 * _shimmer.value,
              ),
            ),
            child: Text(
              'Begin',
              style: AppTextStyles.mono(
                fontSize: 12,
                color: AppColors.quicksand.withValues(
                  alpha: 0.7 + 0.25 * _shimmer.value,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrbitalPainter extends CustomPainter {
  final double progress;
  final double slideOffset;

  _OrbitalPainter({required this.progress, required this.slideOffset});

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * math.pi;
    final center = Offset(size.width * 0.5, size.height * 0.5);

    // Starfield
    final starRng = math.Random(42);
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.22);
    for (int i = 0; i < 90; i++) {
      final x = starRng.nextDouble() * size.width;
      final y = starRng.nextDouble() * size.height;
      final r = starRng.nextDouble() * 1.2;
      canvas.drawCircle(Offset(x, y), r, starPaint);
    }

    // Orbital rings
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = AppColors.shellstone.withValues(alpha: 0.12);

    for (final radius in [
      size.width * 0.38,
      size.width * 0.52,
      size.width * 0.66,
    ]) {
      canvas.drawCircle(center, radius, ringPaint);
    }

    // Orbiting dots
    final dotPaint = Paint()
      ..color = AppColors.shellstone.withValues(alpha: 0.35);
    final orbitConfigs = [
      (size.width * 0.38, t * 0.4 + slideOffset),
      (size.width * 0.52, -t * 0.25 + slideOffset + 1.0),
      (size.width * 0.66, t * 0.15 + slideOffset + 2.5),
    ];

    for (final (radius, angle) in orbitConfigs) {
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }

    // Core glow
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF3C507D).withValues(alpha: 0.55),
              const Color(0xFF1E3A6E).withValues(alpha: 0.25),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.width * 0.34),
          );
    canvas.drawCircle(center, size.width * 0.34, glowPaint);

    // Inner core
    final corePaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF4A6FA5).withValues(alpha: 0.4),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.width * 0.20),
          );
    canvas.drawCircle(center, size.width * 0.20, corePaint);

    // Gold halo ring
    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.quicksand.withValues(alpha: 0.18);
    canvas.drawCircle(center, size.width * 0.26, haloPaint);
  }

  @override
  bool shouldRepaint(_OrbitalPainter old) =>
      old.progress != progress || old.slideOffset != slideOffset;
}
