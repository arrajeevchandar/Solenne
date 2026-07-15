import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/journals/journal_day.dart';
import '../../features/journals/journal_entry.dart';
import '../../routing/fade_through_route.dart';
import '../../theme/app_theme.dart';
import '../insights/daily_insight_screen.dart';

Future<void> openJournalDay(BuildContext context, JournalDay day) async {
  if (day.entries.length == 1) {
    await Navigator.of(
      context,
    ).push(fadeThroughRoute(DailyInsightScreen(entryId: day.latestEntry.id)));
    return;
  }

  final selected = await showModalBottomSheet<JournalEntry>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (sheetContext) => _JournalDayChooser(day: day),
  );
  if (selected == null || !context.mounted) return;
  await Navigator.of(
    context,
  ).push(fadeThroughRoute(DailyInsightScreen(entryId: selected.id)));
}

class _JournalDayChooser extends StatelessWidget {
  const _JournalDayChooser({required this.day});

  final JournalDay day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 14),
      child: SolenneGlass(
        borderRadius: 28,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        tint: AppColors.sapphire,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: AppColors.shellstone.withValues(alpha: 0.28),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              DateFormat('EEEE, d MMMM').format(day.date),
              style: AppTextStyles.display(fontSize: 29),
            ),
            const SizedBox(height: 4),
            Text(
              '${day.entryCount} reflections were recorded. Choose one to revisit.',
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.shellstone.withValues(alpha: 0.68),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 18),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (
                      int index = 0;
                      index < day.entries.length;
                      index++
                    ) ...[
                      _EntryChoice(entry: day.entries[index]),
                      if (index != day.entries.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryChoice extends StatelessWidget {
  const _EntryChoice({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final insightMood = entry.aiInsights.isEmpty
        ? null
        : entry.aiInsights.first.moodLabel.trim();
    final mood = entry.moodLabel?.trim().isNotEmpty == true
        ? entry.moodLabel!.trim()
        : insightMood;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).pop(entry),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: AppColors.royalBlue.withValues(alpha: 0.2),
            border: Border.all(
              color: AppColors.shellstone.withValues(alpha: 0.11),
            ),
          ),
          child: Row(
            children: [
              _EntryThumbnail(entry: entry),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(
                        fontSize: 14,
                        color: AppColors.swanWing.withValues(alpha: 0.94),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        DateFormat('h:mm a').format(entry.recordedAt),
                        _durationLabel(entry.durationSeconds),
                        if (mood != null && mood.isNotEmpty) mood,
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.mono(
                        fontSize: 9,
                        color: AppColors.shellstone.withValues(alpha: 0.56),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                size: 17,
                color: AppColors.quicksand.withValues(alpha: 0.76),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryThumbnail extends StatelessWidget {
  const _EntryThumbnail({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final thumbnail = entry.effectiveThumbnailUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: 58,
        height: 48,
        color: AppColors.sapphire.withValues(alpha: 0.2),
        child: thumbnail.isEmpty
            ? _fallback()
            : Image.network(
                thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback() => Icon(
    Icons.videocam_outlined,
    color: AppColors.quicksand.withValues(alpha: 0.72),
  );
}

String _durationLabel(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
