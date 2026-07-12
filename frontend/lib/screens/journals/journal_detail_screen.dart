import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/journals/journal_entry.dart';
import '../../theme/app_theme.dart';

class JournalDetailScreen extends StatelessWidget {
  const JournalDetailScreen({
    super.key,
    required this.title,
    required this.detail,
    this.entry,
  });

  final String title;
  final String detail;
  final JournalEntry? entry;

  List<String> get _themes {
    final themes = <String>[];
    for (final insight in entry?.aiInsights ?? const <AiInsight>[]) {
      for (final theme in insight.dayThemes) {
        if (theme.trim().isNotEmpty && !themes.contains(theme.trim())) {
          themes.add(theme.trim());
        }
      }
    }
    return themes.isEmpty
        ? const ['clarity', 'rest', 'tomorrow']
        : themes.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SolenneBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 38),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: 'Back to home',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.shellstone.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Journal entry',
                  style: AppTextStyles.mono(
                    fontSize: 10,
                    color: AppColors.quicksand.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(title, style: AppTextStyles.display(fontSize: 36)),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: AppTextStyles.body(
                    fontSize: 13,
                    color: AppColors.shellstone.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: 22),
                const _VideoPlaceholder(),
                const SizedBox(height: 20),
                Text(
                  'A small snapshot',
                  style: AppTextStyles.body(
                    fontSize: 18,
                    color: AppColors.swanWing.withValues(alpha: 0.94),
                  ),
                ),
                const SizedBox(height: 12),
                const _InsightTiles(),
                const SizedBox(height: 20),
                Text(
                  'Present in this entry',
                  style: AppTextStyles.body(
                    fontSize: 18,
                    color: AppColors.swanWing.withValues(alpha: 0.94),
                  ),
                ),
                const SizedBox(height: 10),
                _ThemesCard(themes: _themes),
                const SizedBox(height: 16),
                SolenneGlass(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  borderRadius: 18,
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        size: 19,
                        color: AppColors.quicksand.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          'Video playback and full insights will appear here soon.',
                          style: AppTextStyles.body(
                            fontSize: 12,
                            color: AppColors.shellstone.withValues(alpha: 0.74),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SolenneGlass(
      padding: const EdgeInsets.all(10),
      borderRadius: 22,
      tint: AppColors.sapphire,
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _VideoPlaceholderPainter()),
            ),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.quicksand.withValues(alpha: 0.82),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 34,
                color: AppColors.royalBlue,
              ),
            ),
            Positioned(
              left: 12,
              bottom: 10,
              child: Text(
                'VIDEO PREVIEW',
                style: AppTextStyles.mono(
                  fontSize: 9,
                  color: AppColors.shellstone.withValues(alpha: 0.66),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightTiles extends StatelessWidget {
  const _InsightTiles();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _InsightTile(
            label: 'VOICE',
            value: 'Steady',
            icon: Icons.graphic_eq_rounded,
            progress: 0.68,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _InsightTile(
            label: 'TONE',
            value: 'Open',
            icon: Icons.auto_awesome_outlined,
            progress: 0.54,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _InsightTile(
            label: 'THEMES',
            value: '3',
            icon: Icons.bubble_chart_outlined,
            progress: 0.82,
          ),
        ),
      ],
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.progress,
  });

  final String label;
  final String value;
  final IconData icon;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SolenneGlass(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
      borderRadius: 16,
      child: Column(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CustomPaint(painter: _ArcPainter(progress)),
          ),
          const SizedBox(height: 6),
          Icon(
            icon,
            size: 14,
            color: AppColors.quicksand.withValues(alpha: 0.75),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.mono(
              fontSize: 7,
              color: AppColors.shellstone.withValues(alpha: 0.52),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemesCard extends StatelessWidget {
  const _ThemesCard({required this.themes});

  final List<String> themes;

  @override
  Widget build(BuildContext context) {
    return SolenneGlass(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      tint: AppColors.sapphire,
      child: Column(
        children: [
          SizedBox(
            height: 58,
            width: double.infinity,
            child: CustomPaint(
              painter: _ConstellationPainter(count: themes.length),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 7,
            runSpacing: 7,
            children: [for (final theme in themes) _ThemeChip(label: theme)],
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppColors.sapphire.withValues(alpha: 0.22),
        border: Border.all(color: AppColors.shellstone.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: AppTextStyles.mono(
          fontSize: 9,
          color: AppColors.shellstone.withValues(alpha: 0.76),
        ),
      ),
    );
  }
}

class _VideoPlaceholderPainter extends CustomPainter {
  const _VideoPlaceholderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF182B59), Color(0xFF0B1737), Color(0xFF050A1D)],
        ).createShader(rect),
    );
    final center = Offset(size.width * 0.5, size.height * 0.45);
    for (int index = 0; index < 3; index++) {
      canvas.drawCircle(
        center,
        size.shortestSide * (0.14 + index * 0.11),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = (index == 1 ? AppColors.quicksand : AppColors.shellstone)
              .withValues(alpha: 0.18 + index * 0.08),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = AppColors.shellstone.withValues(alpha: 0.16);
    canvas.drawArc(
      (Offset.zero & size).deflate(2),
      -math.pi / 2,
      math.pi * 2,
      false,
      paint,
    );
    canvas.drawArc(
      (Offset.zero & size).deflate(2),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      paint..color = AppColors.quicksand.withValues(alpha: 0.86),
    );
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ConstellationPainter extends CustomPainter {
  const _ConstellationPainter({required this.count});

  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(31 + count);
    final points = List.generate(
      math.max(4, count + 2),
      (_) => Offset(
        size.width * (0.1 + random.nextDouble() * 0.8),
        size.height * (0.18 + random.nextDouble() * 0.64),
      ),
    );
    final linePaint = Paint()
      ..color = AppColors.shellstone.withValues(alpha: 0.18)
      ..strokeWidth = 0.8;
    for (int index = 1; index < points.length; index++) {
      canvas.drawLine(points[index - 1], points[index], linePaint);
    }
    for (final point in points) {
      canvas.drawCircle(
        point,
        3,
        Paint()..color = AppColors.quicksand.withValues(alpha: 0.88),
      );
    }
  }

  @override
  bool shouldRepaint(_ConstellationPainter oldDelegate) =>
      oldDelegate.count != count;
}
