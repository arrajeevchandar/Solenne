import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'audio_journal_screen.dart';
import 'recording_screen.dart';
import 'written_journal_screen.dart';

class JournalEntryPickerScreen extends StatelessWidget {
  const JournalEntryPickerScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SolenneBackground(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 650;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 34),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0, constraints.maxHeight - 48),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const Spacer(),
                      Text(
                        'Make an entry',
                        style: AppTextStyles.display(
                          fontSize: compact ? 32 : 38,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Choose the form that feels easiest today.',
                        style: AppTextStyles.body(
                          fontSize: compact ? 13 : 15,
                          color: AppColors.shellstone.withValues(alpha: 0.72),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      SizedBox(height: compact ? 18 : 28),
                      _EntryModeTile(
                        icon: Icons.videocam_rounded,
                        title: 'Video journal',
                        detail: 'See and hear the moment as it was.',
                        compact: compact,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RecordingScreen(),
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 8 : 12),
                      _EntryModeTile(
                        icon: Icons.mic_rounded,
                        title: 'Voice journal',
                        detail: 'Say it without being on camera.',
                        compact: compact,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AudioJournalScreen(),
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 8 : 12),
                      _EntryModeTile(
                        icon: Icons.edit_note_rounded,
                        title: 'Written journal',
                        detail: 'Give the day a few honest words.',
                        compact: compact,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const WrittenJournalScreen(),
                          ),
                        ),
                      ),
                      const Spacer(flex: 2),
                      Padding(
                        padding: EdgeInsets.only(top: compact ? 16 : 24),
                        child: Text(
                          'Every format stays private until you share it.',
                          style: AppTextStyles.mono(
                            fontSize: 9,
                            color: AppColors.shellstone.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _EntryModeTile extends StatelessWidget {
  const _EntryModeTile({
    required this.icon,
    required this.title,
    required this.detail,
    required this.compact,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: SolenneGlass(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: compact ? 10 : 16,
      ),
      borderRadius: 20,
      child: Row(
        children: [
          Container(
            width: compact ? 38 : 44,
            height: compact ? 38 : 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.sapphire.withValues(alpha: 0.28),
            ),
            child: Icon(
              icon,
              color: AppColors.quicksand,
              size: compact ? 18 : 21,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body(fontSize: compact ? 15 : 17),
                ),
                Text(
                  detail,
                  style: AppTextStyles.body(
                    fontSize: compact ? 10 : 11,
                    color: AppColors.shellstone.withValues(alpha: 0.66),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, size: 19),
        ],
      ),
    ),
  );
}
