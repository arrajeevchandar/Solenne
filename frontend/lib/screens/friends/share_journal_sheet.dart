import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_providers.dart';
import '../../features/journals/journal_entry.dart';
import '../../features/social/social_models.dart';
import '../../features/social/social_repository.dart';
import '../../theme/app_theme.dart';

Future<void> showShareJournalSheet(
  BuildContext context, {
  required JournalEntry entry,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (context) => _ShareJournalSheet(entry: entry),
  );
}

class _ShareJournalSheet extends ConsumerStatefulWidget {
  const _ShareJournalSheet({required this.entry});

  final JournalEntry entry;

  @override
  ConsumerState<_ShareJournalSheet> createState() => _ShareJournalSheetState();
}

class _ShareJournalSheetState extends ConsumerState<_ShareJournalSheet> {
  final _selectedFriends = <String>{};
  bool _includeTranscript = false;
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final friendships = ref.watch(friendshipsProvider);
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 14),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: SolenneGlass(
          borderRadius: 26,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          tint: AppColors.sapphire,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      color: AppColors.shellstone.withValues(alpha: 0.28),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Share this journal',
                  style: AppTextStyles.display(fontSize: 29),
                ),
                const SizedBox(height: 5),
                Text(
                  entry.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                    fontSize: 13,
                    color: AppColors.shellstone.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 17),
                Text(
                  'Choose friends',
                  style: AppTextStyles.mono(
                    fontSize: 9,
                    color: AppColors.quicksand.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 8),
                if (friendships.isEmpty)
                  Text(
                    'Add a friend to your circle before sharing.',
                    style: AppTextStyles.body(fontSize: 12),
                  ),
                for (final friendship in friendships) ...[
                  _FriendSelector(
                    friend: friendship.other(uid),
                    selected: _selectedFriends.contains(friendship.id),
                    onTap: () => setState(() {
                      if (_selectedFriends.contains(friendship.id)) {
                        _selectedFriends.remove(friendship.id);
                      } else {
                        _selectedFriends.add(friendship.id);
                      }
                    }),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 5),
                if (!entry.isWritten)
                  _IncludeReflectionRow(
                    value: _includeTranscript,
                    onChanged: (value) =>
                        setState(() => _includeTranscript = value),
                  ),
                const SizedBox(height: 14),
                Text(
                  'Friends can see this entry only. Your private timeline, raw analytics, and other journals remain private.',
                  style: AppTextStyles.body(
                    fontSize: 10,
                    color: AppColors.shellstone.withValues(alpha: 0.54),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: AppTextStyles.body(
                      fontSize: 11,
                      color: AppColors.quicksand,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        _selectedFriends.isEmpty ||
                            _saving ||
                            entry.analysisStatus != 'complete'
                        ? null
                        : () async {
                            setState(() {
                              _saving = true;
                              _error = null;
                            });
                            try {
                              await ref
                                  .read(socialRepositoryProvider)
                                  .shareJournal(
                                    entry: entry,
                                    friendships: friendships.where(
                                      (item) =>
                                          _selectedFriends.contains(item.id),
                                    ),
                                    includeTranscript: _includeTranscript,
                                  );
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Journal shared.'),
                                ),
                              );
                            } catch (error) {
                              if (mounted) {
                                setState(() => _error = error.toString());
                              }
                            } finally {
                              if (mounted) setState(() => _saving = false);
                            }
                          },
                    icon: const Icon(Icons.lock_open_rounded, size: 17),
                    label: Text(
                      entry.analysisStatus == 'complete'
                          ? _saving
                                ? 'Sharing...'
                                : 'Share selected entry'
                          : 'Insights must finish first',
                    ),
                    style: FilledButton.styleFrom(
                      foregroundColor: AppColors.royalBlue,
                      backgroundColor: AppColors.quicksand,
                      disabledForegroundColor: AppColors.shellstone.withValues(
                        alpha: 0.5,
                      ),
                      disabledBackgroundColor: AppColors.sapphire.withValues(
                        alpha: 0.22,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FriendSelector extends StatelessWidget {
  const _FriendSelector({
    required this.friend,
    required this.selected,
    required this.onTap,
  });

  final PublicProfile friend;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(15),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: selected
            ? AppColors.quicksand.withValues(alpha: 0.1)
            : AppColors.royalBlue.withValues(alpha: 0.16),
        border: Border.all(
          color: selected
              ? AppColors.quicksand.withValues(alpha: 0.38)
              : AppColors.shellstone.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 33,
            height: 33,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.sapphire.withValues(alpha: 0.32),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 16,
              color: AppColors.quicksand,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.displayName,
                  style: AppTextStyles.body(fontSize: 13),
                ),
                Text(
                  '@${friend.username}',
                  style: AppTextStyles.mono(
                    fontSize: 8,
                    color: AppColors.shellstone.withValues(alpha: 0.52),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            selected ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 20,
            color: selected
                ? AppColors.quicksand
                : AppColors.shellstone.withValues(alpha: 0.4),
          ),
        ],
      ),
    ),
  );
}

class _IncludeReflectionRow extends StatelessWidget {
  const _IncludeReflectionRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        Icons.auto_awesome_outlined,
        size: 17,
        color: AppColors.quicksand.withValues(alpha: 0.72),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          'Include the generated transcript',
          style: AppTextStyles.body(
            fontSize: 12,
            color: AppColors.shellstone.withValues(alpha: 0.76),
          ),
        ),
      ),
      Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.quicksand.withValues(alpha: 0.58),
        activeThumbColor: AppColors.swanWing,
      ),
    ],
  );
}
