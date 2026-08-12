import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'recording_screen.dart';

class JournalEntryPickerScreen extends StatelessWidget {
  const JournalEntryPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SolenneBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: AppColors.shellstone.withValues(alpha: 0.78),
                ),
                const Spacer(),
                Text(
                  'Make an entry',
                  style: AppTextStyles.display(fontSize: 38),
                ),
                const SizedBox(height: 7),
                Text(
                  'Choose the form that feels easiest today.',
                  style: AppTextStyles.body(
                    fontSize: 15,
                    color: AppColors.shellstone.withValues(alpha: 0.72),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 28),
                _EntryModeTile(
                  icon: Icons.videocam_rounded,
                  title: 'Video journal',
                  detail: 'See and hear the moment as it was.',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RecordingScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _EntryModeTile(
                  icon: Icons.mic_rounded,
                  title: 'Voice journal',
                  detail: 'Say it without being on camera.',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const VoiceJournalScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _EntryModeTile(
                  icon: Icons.edit_note_rounded,
                  title: 'Written journal',
                  detail: 'Give the day a few honest words.',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const WrittenJournalScreen(),
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                Text(
                  'Every format stays private to you.',
                  style: AppTextStyles.mono(
                    fontSize: 9,
                    color: AppColors.shellstone.withValues(alpha: 0.5),
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

class VoiceJournalScreen extends StatefulWidget {
  const VoiceJournalScreen({super.key});

  @override
  State<VoiceJournalScreen> createState() => _VoiceJournalScreenState();
}

class _VoiceJournalScreenState extends State<VoiceJournalScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  Timer? _timer;
  bool _recording = false;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleRecording() {
    setState(() => _recording = !_recording);
    if (_recording) {
      _animationController.repeat(reverse: true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    } else {
      _animationController.stop();
      _timer?.cancel();
    }
  }

  void _savePreview() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Voice journals are ready for backend saving in the next phase.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !_recording && _seconds > 0;
    return Scaffold(
      body: SolenneBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 34),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.shellstone.withValues(alpha: 0.78),
                    ),
                    const Spacer(),
                    Text(
                      'VOICE JOURNAL',
                      style: AppTextStyles.mono(
                        fontSize: 10,
                        color: AppColors.shellstone.withValues(alpha: 0.52),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  _recording ? 'I\'m listening' : 'Speak freely',
                  style: AppTextStyles.display(fontSize: 36),
                ),
                const SizedBox(height: 8),
                Text(
                  _recording
                      ? _formatDuration(_seconds)
                      : 'Your camera stays off for this one.',
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.shellstone.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 34),
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, _) => SizedBox(
                    width: 220,
                    height: 220,
                    child: CustomPaint(
                      painter: _VoiceOrbPainter(
                        progress: _animationController.value,
                        active: _recording,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Tooltip(
                  message: _recording
                      ? 'Pause voice recording'
                      : 'Start voice recording',
                  child: InkWell(
                    onTap: _toggleRecording,
                    borderRadius: BorderRadius.circular(40),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _recording
                            ? AppColors.sapphire.withValues(alpha: 0.5)
                            : AppColors.quicksand.withValues(alpha: 0.84),
                        border: Border.all(
                          color: AppColors.shellstone.withValues(alpha: 0.34),
                        ),
                      ),
                      child: Icon(
                        _recording ? Icons.pause_rounded : Icons.mic_rounded,
                        color: _recording
                            ? AppColors.quicksand
                            : AppColors.royalBlue,
                        size: 31,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                TextButton.icon(
                  onPressed: canSave ? _savePreview : null,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                  label: const Text('Continue'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.quicksand,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }
}

class WrittenJournalScreen extends StatefulWidget {
  const WrittenJournalScreen({super.key});

  @override
  State<WrittenJournalScreen> createState() => _WrittenJournalScreenState();
}

class _WrittenJournalScreenState extends State<WrittenJournalScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _savePreview() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Written journals are ready for backend saving in the next phase.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasWords = _bodyController.text.trim().isNotEmpty;
    return Scaffold(
      body: SolenneBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.shellstone.withValues(alpha: 0.78),
                    ),
                    const Spacer(),
                    Text(
                      'WRITTEN JOURNAL',
                      style: AppTextStyles.mono(
                        fontSize: 10,
                        color: AppColors.shellstone.withValues(alpha: 0.52),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'A page for today',
                  style: AppTextStyles.display(fontSize: 34),
                ),
                const SizedBox(height: 6),
                Text(
                  'Write only what you want to keep.',
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.shellstone.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 22),
                SolenneGlass(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  borderRadius: 18,
                  child: TextField(
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                    textCapitalization: TextCapitalization.sentences,
                    style: AppTextStyles.body(fontSize: 17),
                    decoration: InputDecoration(
                      hintText: 'Give this entry a name',
                      hintStyle: AppTextStyles.body(
                        fontSize: 15,
                        color: AppColors.shellstone.withValues(alpha: 0.44),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SolenneGlass(
                    padding: const EdgeInsets.all(16),
                    borderRadius: 20,
                    child: TextField(
                      controller: _bodyController,
                      onChanged: (_) => setState(() {}),
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      textCapitalization: TextCapitalization.sentences,
                      style: AppTextStyles.body(
                        fontSize: 16,
                        color: AppColors.swanWing.withValues(alpha: 0.9),
                      ),
                      decoration: InputDecoration(
                        hintText: 'What is sitting with you?',
                        hintStyle: AppTextStyles.body(
                          fontSize: 15,
                          color: AppColors.shellstone.withValues(alpha: 0.48),
                          fontStyle: FontStyle.italic,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '${_wordCount(_bodyController.text)} words',
                      style: AppTextStyles.mono(
                        fontSize: 9,
                        color: AppColors.shellstone.withValues(alpha: 0.48),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: hasWords ? _savePreview : null,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                      label: const Text('Continue'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.quicksand,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static int _wordCount(String value) =>
      RegExp(r"\S+").allMatches(value).length;
}

class _EntryModeTile extends StatelessWidget {
  const _EntryModeTile({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: SolenneGlass(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      borderRadius: 20,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.sapphire.withValues(alpha: 0.28),
            ),
            child: Icon(icon, color: AppColors.quicksand, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.body(fontSize: 17)),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: AppTextStyles.body(
                    fontSize: 11,
                    color: AppColors.shellstone.withValues(alpha: 0.66),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_rounded,
            size: 19,
            color: AppColors.shellstone.withValues(alpha: 0.5),
          ),
        ],
      ),
    ),
  );
}

class _VoiceOrbPainter extends CustomPainter {
  const _VoiceOrbPainter({required this.progress, required this.active});

  final double progress;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.sapphire.withValues(alpha: active ? 0.68 : 0.4),
            AppColors.royalBlue.withValues(alpha: 0.24),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    for (int ring = 0; ring < 4; ring++) {
      final ringRadius =
          radius * (0.3 + ring * 0.15 + (active ? progress * 0.025 : 0));
      final path = Path();
      for (int step = 0; step <= 72; step++) {
        final angle = step / 72 * math.pi * 2;
        final wave =
            math.sin(angle * (ring + 3) + progress * math.pi * 2) *
            (active ? 7 : 3);
        final point = Offset(
          center.dx + math.cos(angle) * (ringRadius + wave),
          center.dy + math.sin(angle) * (ringRadius + wave),
        );
        if (step == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = (ring == 2 ? AppColors.quicksand : AppColors.shellstone)
              .withValues(alpha: active ? 0.28 : 0.16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(_VoiceOrbPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.active != active;
}
