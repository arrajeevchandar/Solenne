import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/social/social_repository.dart';
import '../../theme/app_theme.dart';

class SharingSettingsScreen extends ConsumerWidget {
  const SharingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shares = ref.watch(outgoingSharesProvider);
    return Scaffold(
      body: SolenneBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 38),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Spacer(),
                    Text('SHARING', style: AppTextStyles.mono(fontSize: 9)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Your sharing circle',
                  style: AppTextStyles.display(fontSize: 34),
                ),
                const SizedBox(height: 5),
                Text(
                  'Only the journals listed here are visible to a friend.',
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.shellstone.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 20),
                shares.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _Notice(error.toString()),
                  data: (items) => items.isEmpty
                      ? const _Notice('You have not shared a journal yet.')
                      : Column(
                          children: [
                            for (final share in items) ...[
                              SolenneGlass(
                                padding: const EdgeInsets.all(15),
                                borderRadius: 18,
                                child: Row(
                                  children: [
                                    Icon(
                                      share.entry.isWritten
                                          ? Icons.edit_note_rounded
                                          : share.entry.isAudio
                                          ? Icons.graphic_eq_rounded
                                          : Icons.videocam_outlined,
                                      color: AppColors.quicksand,
                                    ),
                                    const SizedBox(width: 11),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            share.entry.displayTitle,
                                            style: AppTextStyles.body(
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            'Shared with @${share.recipient.username} · ${DateFormat('d MMM').format(share.sharedAt)}',
                                            style: AppTextStyles.mono(
                                              fontSize: 8,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Stop sharing',
                                      onPressed: () => ref
                                          .read(socialRepositoryProvider)
                                          .revokeShare(share.shareId),
                                      icon: const Icon(Icons.lock_rounded),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 9),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                const _Notice(
                  'Raw wellbeing metrics and diagnostics are never included. Prototype media links can still be copied outside the app.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => SolenneGlass(
    padding: const EdgeInsets.all(16),
    borderRadius: 18,
    child: Text(
      text,
      style: AppTextStyles.body(
        fontSize: 12,
        color: AppColors.shellstone.withValues(alpha: 0.7),
      ),
    ),
  );
}
