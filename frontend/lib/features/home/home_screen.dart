import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/organic_background.dart';
import '../../core/widgets/solenne_button.dart';
import '../../core/widgets/solenne_card.dart';
import '../../core/widgets/solenne_visuals.dart';
import '../auth/auth_providers.dart';
import '../journals/journal_entry.dart';
import '../journals/journal_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final journals = ref.watch(journalStreamProvider);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';

    return Scaffold(
      body: OrganicBackground(
        showGrid: true,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            children: [
              SolenneSectionTitle(
                title: '$greeting, ${user?.displayName ?? 'friend'}',
                subtitle: DateFormat('EEEE, MMMM d').format(DateTime.now()),
                trailing: IconButton.filled(
                  onPressed: () => context.go('/profile'),
                  icon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 22),
              journals.when(
                data: (items) => _HomeLoaded(items: items),
                loading: () => Column(
                  children: const [
                    SizedBox(height: 20),
                    CircularProgressIndicator(),
                    SizedBox(height: 18),
                    _PromptCard(status: 'Checking your latest reflection...'),
                  ],
                ),
                error: (error, stackTrace) => Column(
                  children: [
                    const _PromptCard(status: 'Ready when you are.'),
                    const SizedBox(height: 18),
                    SolenneCard(child: Text(error.toString())),
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

class _HomeLoaded extends StatelessWidget {
  const _HomeLoaded({required this.items});

  final List<JournalEntry> items;

  @override
  Widget build(BuildContext context) {
    final todaySaved = items.any(
      (item) => DateUtils.isSameDay(item.recordedAt, DateTime.now()),
    );
    final weekValues = List<int>.generate(7, (index) {
      final date = DateTime.now().subtract(Duration(days: 6 - index));
      return items
          .where((item) => DateUtils.isSameDay(item.recordedAt, date))
          .length;
    });

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SolenneMetricTile(
                icon: Icons.local_fire_department_rounded,
                value: '${items.length}',
                label: 'saved',
                color: AppColors.gold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SolenneMetricTile(
                icon: Icons.videocam_rounded,
                value: todaySaved ? '1' : '0',
                label: 'today',
                color: AppColors.violet,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: SolenneMetricTile(
                icon: Icons.lock_outline_rounded,
                value: 'Private',
                label: 'always',
                color: AppColors.aqua,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _PromptCard(
          status: todaySaved
              ? 'Saved for today. You can still add another reflection.'
              : 'A short check-in can help you notice what changed today.',
        ),
        const SizedBox(height: 18),
        SolenneCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This week', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 10),
              SolenneActivityBars(values: weekValues),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _RecentJournals(items: items),
      ],
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [
            AppColors.aqua.withValues(alpha: 0.18),
            AppColors.violet.withValues(alpha: 0.11),
            AppColors.glassStrong,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.aqua.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.aqua.withValues(alpha: 0.14),
            blurRadius: 38,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's prompt",
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.aqua,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '"What brought you calm this morning?"',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(status, style: Theme.of(context).textTheme.bodyMedium),
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

class _RecentJournals extends StatelessWidget {
  const _RecentJournals({required this.items});

  final List<JournalEntry> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent', style: Theme.of(context).textTheme.titleLarge),
            TextButton(
              onPressed: () => context.go('/journals'),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          SolenneCard(
            child: Text(
              'Your first reflection will appear here.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          ...items.take(3).map((entry) {
            return SolenneVideoTile(
              title: entry.prompt,
              subtitle: DateFormat('MMM d, h:mm a').format(entry.recordedAt),
              thumbnailUrl: entry.thumbnailUrl,
              color: AppColors.aqua,
              onTap: () => context.go('/journals/${entry.id}'),
            );
          }),
      ],
    );
  }
}
