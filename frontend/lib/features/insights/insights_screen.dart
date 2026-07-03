import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/organic_background.dart';
import '../../core/widgets/solenne_button.dart';
import '../../core/widgets/solenne_card.dart';
import '../../core/widgets/solenne_visuals.dart';
import '../journals/journal_repository.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journals = ref.watch(journalStreamProvider);
    return Scaffold(
      body: OrganicBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
            children: [
              const SectionLabel('Insight room'),
              const SizedBox(height: 8),
              Text(
                'Patterns will live here',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'This screen is ready for backend AI insights later. For now it reflects saved journal activity only.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 22),
              journals.when(
                data: (items) {
                  final totalSeconds = items.fold<int>(
                    0,
                    (sum, entry) => sum + entry.durationSeconds,
                  );
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: MetricTile(
                              label: 'Entries',
                              value: '${items.length}',
                              icon: Icons.video_library_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MetricTile(
                              label: 'Minutes',
                              value: '${(totalSeconds / 60).ceil()}',
                              icon: Icons.timer_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SolenneCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionLabel('Current read'),
                            const SizedBox(height: 10),
                            Text(
                              items.isEmpty
                                  ? 'Your first reflection will create the baseline.'
                                  : 'You have ${items.length} saved reflections ready for future analysis.',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Backend analysis will later add mood themes, transcript summaries, and gentle day-level suggestions here.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SolenneCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionLabel('Next reflection prompt'),
                            const SizedBox(height: 10),
                            Text(
                              'What felt heavier than expected today, and what helped you move through it?',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            SolenneButton(
                              label: 'Record This Prompt',
                              icon: Icons.radio_button_checked,
                              onPressed: () => context.go('/record'),
                            ),
                          ],
                        ),
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
