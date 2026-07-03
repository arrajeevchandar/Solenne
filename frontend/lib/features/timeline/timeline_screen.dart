import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/organic_background.dart';
import '../../core/widgets/solenne_button.dart';
import '../../core/widgets/solenne_card.dart';
import '../../core/widgets/solenne_visuals.dart';
import '../journals/journal_entry.dart';
import '../journals/journal_repository.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journals = ref.watch(journalStreamProvider);
    return Scaffold(
      body: OrganicBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
            children: [
              const SectionLabel('Private timeline'),
              const SizedBox(height: 8),
              Text(
                'Your reflection arc',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Saved video entries appear here as a quiet trail you can revisit.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 22),
              journals.when(
                data: (items) {
                  if (items.isEmpty) return const _EmptyTimeline();
                  return Column(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        _TimelineEntry(
                          entry: items[i],
                          isLast: i == items.length - 1,
                        ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => SolenneCard(child: Text(error.toString())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();

  @override
  Widget build(BuildContext context) {
    return SolenneCard(
      child: Column(
        children: [
          const SolenneOrb(size: 78),
          const SizedBox(height: 18),
          Text('No entries yet', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Record a first reflection and Solenne will begin building your private timeline.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          SolenneButton(
            label: 'Begin Reflection',
            icon: Icons.videocam_rounded,
            onPressed: () => context.go('/record'),
          ),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.entry, required this.isLast});

  final JournalEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: AppColors.quicksand,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      color: AppColors.shellstone.withValues(alpha: 0.22),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () => context.go('/journals/${entry.id}'),
                child: SolenneCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 70,
                        height: 82,
                        decoration: BoxDecoration(
                          color: AppColors.sapphire.withValues(alpha: 0.56),
                          borderRadius: BorderRadius.circular(22),
                          image: !entry.hasImageThumbnail
                              ? null
                              : DecorationImage(
                                  image: NetworkImage(entry.thumbnailUrl),
                                  fit: BoxFit.cover,
                                ),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, size: 34),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat(
                                'MMM d, h:mm a',
                              ).format(entry.recordedAt),
                              style: AppTextStyles.monoLabel,
                            ),
                            const SizedBox(height: 7),
                            Text(
                              entry.prompt,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 9),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _Chip('${entry.durationSeconds}s'),
                                _Chip(entry.uploadStatus),
                                _Chip(
                                  entry.analysisStatus.replaceAll('_', ' '),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.royalBlue.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.swanWing.withValues(alpha: 0.11)),
      ),
      child: Text(label, style: AppTextStyles.monoLabel),
    );
  }
}
