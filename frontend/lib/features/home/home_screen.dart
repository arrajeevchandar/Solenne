import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/organic_background.dart';
import '../../core/widgets/solenne_button.dart';
import '../../core/widgets/solenne_card.dart';
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
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting, ${user?.displayName ?? 'friend'}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 6),
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
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                    colors: [AppColors.pastelBlue, AppColors.softSage],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today’s reflection', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      journals.when(
                        data: (items) => items.any((item) =>
                                DateUtils.isSameDay(item.recordedAt, DateTime.now()))
                            ? 'Saved for today. You can still add another reflection.'
                            : 'A short check-in can help you notice what changed today.',
                        loading: () => 'Checking your latest reflection...',
                        error: (error, stackTrace) => 'Ready when you are.',
                      ),
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
              const SizedBox(height: 18),
              SolenneCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily prompt', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(_prompt, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: 'Current streak',
                      value: journals.maybeWhen(
                        data: (items) => '${items.length}',
                        orElse: () => '0',
                      ),
                      label: 'saved reflections',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _MetricCard(
                      title: 'Status',
                      value: 'Private',
                      label: 'stored to your account',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent journals', style: Theme.of(context).textTheme.titleLarge),
                  TextButton(
                    onPressed: () => context.go('/journals'),
                    child: const Text('View all'),
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
                          backgroundColor: AppColors.blushPink,
                          child: const Icon(Icons.play_arrow_rounded),
                        ),
                        title: Text(entry.prompt),
                        subtitle: Text(DateFormat('MMM d, h:mm a').format(entry.recordedAt)),
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.label});

  final String title;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SolenneCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
