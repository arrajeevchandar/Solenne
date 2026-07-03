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
import 'journal_entry.dart';
import 'journal_repository.dart';

class JournalListScreen extends ConsumerWidget {
  const JournalListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journals = ref.watch(journalStreamProvider);
    return Scaffold(
      body: OrganicBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
            children: [
              const SectionLabel('Archive'),
              const SizedBox(height: 8),
              Text(
                'My Journals',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Saved video reflections, ready to revisit.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              journals.when(
                data: (items) {
                  if (items.isEmpty) return const _EmptyJournals();
                  return Column(
                    children: items
                        .map((entry) => _JournalCard(entry: entry))
                        .toList(),
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

class _EmptyJournals extends StatelessWidget {
  const _EmptyJournals();

  @override
  Widget build(BuildContext context) {
    return SolenneCard(
      child: Column(
        children: [
          const SolenneOrb(size: 82),
          const SizedBox(height: 16),
          Text(
            'Record your first reflection',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Start with a short check-in. You can watch it back after it is saved.',
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

class _JournalCard extends StatelessWidget {
  const _JournalCard({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => context.go('/journals/${entry.id}'),
        child: SolenneCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 78,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.sapphire.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(24),
                  image: !entry.hasImageThumbnail
                      ? null
                      : DecorationImage(
                          image: NetworkImage(entry.thumbnailUrl),
                          fit: BoxFit.cover,
                        ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.quicksand,
                  size: 36,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.prompt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('MMM d, y - h:mm a').format(entry.recordedAt),
                      style: AppTextStyles.monoLabel,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Badge(label: entry.uploadStatus),
                        _Badge(
                          label: entry.analysisStatus.replaceAll('_', ' '),
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
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: AppColors.royalBlue.withValues(alpha: 0.42),
      side: BorderSide(color: AppColors.swanWing.withValues(alpha: 0.10)),
    );
  }
}
