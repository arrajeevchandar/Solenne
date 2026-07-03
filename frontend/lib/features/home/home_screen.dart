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
import '../journals/journal_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _prompt = 'What is one moment from today you want to remember?';

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
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
            children: [
              Row(
                children: [
                  const SolenneOrb(size: 58),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting, ${user?.displayName ?? 'friend'}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          DateFormat('EEEE, MMMM d').format(DateTime.now()),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () => context.go('/profile'),
                    icon: const Icon(Icons.person_outline),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SolenneCard(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Today'),
                    const SizedBox(height: 10),
                    Text(
                      'Today\'s reflection',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 30),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      journals.when(
                        data: (items) =>
                            items.any(
                              (item) => DateUtils.isSameDay(
                                item.recordedAt,
                                DateTime.now(),
                              ),
                            )
                            ? 'Saved for today. You can still add another reflection.'
                            : 'A short check-in can help you notice what changed today.',
                        loading: () => 'Checking your latest reflection...',
                        error: (error, stackTrace) => 'Ready when you are.',
                      ),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 18),
                    SolenneButton(
                      label: 'Begin Reflection',
                      icon: Icons.videocam_rounded,
                      onPressed: () => context.go('/record'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: 'Saved reflections',
                      value: journals.maybeWhen(
                        data: (items) => '${items.length}',
                        orElse: () => '0',
                      ),
                      icon: Icons.auto_stories_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: MetricTile(
                      label: 'Private account',
                      value: 'Safe',
                      icon: Icons.lock_outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SolenneCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Daily prompt'),
                    const SizedBox(height: 10),
                    Text(
                      _prompt,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent journals',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () => context.go('/timeline'),
                    child: const Text('View timeline'),
                  ),
                ],
              ),
              journals.when(
                data: (items) {
                  if (items.isEmpty) {
                    return Text(
                      'Your first reflection will appear here.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    );
                  }
                  return Column(
                    children: items.take(3).map((entry) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.quicksand,
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: AppColors.royalBlue,
                          ),
                        ),
                        title: Text(entry.prompt),
                        subtitle: Text(
                          DateFormat('MMM d, h:mm a').format(entry.recordedAt),
                        ),
                        onTap: () => context.go('/journals/${entry.id}'),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Text(error.toString()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
