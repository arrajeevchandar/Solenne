import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/solenne_notice.dart';
import '../../features/social/social_models.dart';
import '../../features/social/social_repository.dart';
import '../../theme/app_theme.dart';

class SharingSettingsScreen extends ConsumerStatefulWidget {
  const SharingSettingsScreen({super.key});

  @override
  ConsumerState<SharingSettingsScreen> createState() =>
      _SharingSettingsScreenState();
}

class _SharingSettingsScreenState extends ConsumerState<SharingSettingsScreen> {
  final Set<String> _revoking = <String>{};

  Future<void> _unshare(SharedJournalEntry share) async {
    if (_revoking.contains(share.shareId)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF14264F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: AppColors.quicksand.withValues(alpha: 0.42)),
        ),
        title: Text(
          'Stop sharing?',
          style: AppTextStyles.display(fontSize: 27),
        ),
        content: Text(
          '@${share.recipient.username} will no longer see “${share.entry.displayTitle}” in Solenne.',
          style: AppTextStyles.body(
            fontSize: 13,
            color: AppColors.shellstone.withValues(alpha: 0.78),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Keep sharing',
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.shellstone,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.lock_rounded, size: 17),
            label: Text(
              'Unshare',
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.quicksand,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _revoking.add(share.shareId));
    try {
      await ref.read(socialRepositoryProvider).revokeShare(share.shareId);
      if (!mounted) return;
      SolenneNotice.show(
        context,
        message:
            'This journal is no longer shared with @${share.recipient.username}.',
        icon: Icons.lock_outline_rounded,
      );
    } catch (_) {
      if (!mounted) return;
      SolenneNotice.show(
        context,
        message: 'The journal could not be unshared. Please try again.',
        icon: Icons.cloud_off_rounded,
      );
    } finally {
      if (mounted) setState(() => _revoking.remove(share.shareId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final shares = ref.watch(outgoingSharesProvider);
    return Scaffold(
      body: SolenneBackground(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
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
                        Text(
                          'SHARING',
                          style: AppTextStyles.mono(
                            fontSize: 8,
                            color: AppColors.shellstone.withValues(alpha: 0.52),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'Shared by me',
                      style: AppTextStyles.display(fontSize: 36),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Only these chosen reflections are visible inside your friends’ circles.',
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: AppColors.shellstone.withValues(alpha: 0.72),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: shares.when(
                        loading: () => const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                        ),
                        error: (_, _) => _RetryNotice(
                          onRetry: () => ref.invalidate(outgoingSharesProvider),
                        ),
                        data: (items) => items.isEmpty
                            ? const _EmptySharingShelf()
                            : ListView.separated(
                                padding: const EdgeInsets.only(bottom: 18),
                                itemCount: items.length + 1,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  if (index == items.length) {
                                    return const _PrivacyNotice();
                                  }
                                  final share = items[index];
                                  return _OutgoingShareCard(
                                    share: share,
                                    revoking: _revoking.contains(share.shareId),
                                    onUnshare: () => _unshare(share),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutgoingShareCard extends StatelessWidget {
  const _OutgoingShareCard({
    required this.share,
    required this.revoking,
    required this.onUnshare,
  });

  final SharedJournalEntry share;
  final bool revoking;
  final VoidCallback onUnshare;

  @override
  Widget build(BuildContext context) => SolenneGlass(
    padding: const EdgeInsets.all(15),
    borderRadius: 20,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.quicksand.withValues(alpha: 0.1),
                border: Border.all(
                  color: AppColors.quicksand.withValues(alpha: 0.34),
                ),
              ),
              child: Icon(
                share.entry.isWritten
                    ? Icons.edit_note_rounded
                    : share.entry.isAudio
                    ? Icons.graphic_eq_rounded
                    : Icons.videocam_outlined,
                color: AppColors.quicksand,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    share.entry.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(fontSize: 15),
                  ),
                  Text(
                    '${DateFormat('d MMM yyyy').format(share.entry.recordedAt)}  ·  ${share.entry.entryType} journal',
                    style: AppTextStyles.mono(fontSize: 7),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.royalBlue.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.swanWing.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: AppColors.shellstone,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Shared with @${share.recipient.username}  ·  ${DateFormat('d MMM').format(share.sharedAt)}',
                  style: AppTextStyles.mono(fontSize: 8),
                ),
              ),
              TextButton.icon(
                onPressed: revoking ? null : onUnshare,
                icon: revoking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.3),
                      )
                    : const Icon(Icons.lock_rounded, size: 16),
                label: const Text('Unshare'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EmptySharingShelf extends StatelessWidget {
  const _EmptySharingShelf();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: SolenneGlass(
      padding: const EdgeInsets.all(22),
      borderRadius: 22,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.quicksand.withValues(alpha: 0.1),
              border: Border.all(
                color: AppColors.quicksand.withValues(alpha: 0.4),
              ),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.quicksand,
            ),
          ),
          const SizedBox(height: 13),
          Text(
            'Nothing is being shared.',
            style: AppTextStyles.display(fontSize: 24),
          ),
          const SizedBox(height: 4),
          Text(
            'Share a completed reflection from its journal page and it will appear here.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              fontSize: 12,
              color: AppColors.shellstone.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    ),
  );
}

class _RetryNotice extends StatelessWidget {
  const _RetryNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: SolenneGlass(
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.quicksand),
          const SizedBox(height: 10),
          Text(
            'Your sharing shelf could not be opened just now.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(fontSize: 13),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) => SolenneGlass(
    padding: const EdgeInsets.all(15),
    borderRadius: 18,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.shield_outlined, size: 19, color: AppColors.quicksand),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Raw wellbeing metrics and diagnostics are never included. Prototype media links can still be copied outside the app.',
            style: AppTextStyles.body(
              fontSize: 11,
              color: AppColors.shellstone.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    ),
  );
}
