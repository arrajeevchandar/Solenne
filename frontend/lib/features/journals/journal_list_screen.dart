import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            children: [
              const SolenneSectionTitle(
                title: 'My Journals',
                subtitle: 'Your saved video reflections, ready to revisit.',
              ),
              const SizedBox(height: 20),
              SolenneCard(
                padding: const EdgeInsets.all(6),
                child: const Row(
                  children: [
                    Expanded(
                      child: _JournalTab(label: 'All Entries', selected: true),
                    ),
                    Expanded(
                      child: _JournalTab(label: 'Favorites', selected: false),
                    ),
                  ],
                ),
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
          const Icon(
            Icons.play_circle_outline_rounded,
            size: 58,
            color: AppColors.aqua,
          ),
          const SizedBox(height: 14),
          Text(
            'Record your first reflection',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Start with a short check-in. You can watch it back after it is saved.',
            textAlign: TextAlign.center,
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
    return SolenneVideoTile(
      title: entry.prompt,
      subtitle:
          '${DateFormat('MMM d, y - h:mm a').format(entry.recordedAt)} - ${entry.durationSeconds}s',
      thumbnailUrl: entry.thumbnailUrl,
      color: _entryColor(entry.id),
      onTap: () => context.go('/journals/${entry.id}'),
      chips: [
        SolenneStatusChip(
          label: entry.uploadStatus,
          icon: Icons.cloud_done_outlined,
        ),
        SolenneStatusChip(
          label: entry.analysisStatus.replaceAll('_', ' '),
          color: AppColors.violet,
        ),
      ],
    );
  }

  Color _entryColor(String id) {
    final colors = [AppColors.aqua, AppColors.violet, AppColors.coral];
    return colors[id.hashCode.abs() % colors.length];
  }
}

class _JournalTab extends StatelessWidget {
  const _JournalTab({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: selected ? AppColors.cardElevated : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: selected ? AppColors.textPrimary : AppColors.textSecondary,
        ),
      ),
    );
  }
}
