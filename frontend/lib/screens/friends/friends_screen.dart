import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/auth/auth_providers.dart';
import '../../features/auth/profile_avatar.dart';
import '../../core/widgets/solenne_audio_player.dart';
import '../../features/social/social_models.dart';
import '../../features/social/social_repository.dart';
import '../../theme/app_theme.dart';
import '../insights/daily_insight_screen.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<PublicProfile> _matches = const [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    final normalized = AuthRepository.normalizeUsername(value);
    if (normalized.length < 3) {
      setState(() {
        _matches = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final matches = await ref
            .read(socialRepositoryProvider)
            .searchProfiles(normalized);
        if (mounted) setState(() => _matches = matches);
      } catch (error) {
        if (mounted) setState(() => _error = error.toString());
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _perform(Future<void> Function() action) async {
    setState(() => _error = null);
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid ?? '';
    final relationships = ref.watch(relationshipsProvider).value ?? const [];
    final incoming =
        ref.watch(incomingFriendRequestsProvider).value ?? const [];
    final friends = relationships
        .where((item) => item.status == 'accepted')
        .toList(growable: false);
    final query = AuthRepository.normalizeUsername(_searchController.text);

    return Scaffold(
      body: SolenneBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              widget.embedded ? 106 : 36,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!widget.embedded)
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      )
                    else
                      const SizedBox(width: 12),
                    const Spacer(),
                    Text(
                      'YOUR CIRCLE',
                      style: AppTextStyles.mono(
                        fontSize: 9,
                        color: AppColors.shellstone.withValues(alpha: 0.52),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Your circle', style: AppTextStyles.display(fontSize: 34)),
                const SizedBox(height: 5),
                Text(
                  'Find people by username and share only what you choose.',
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.shellstone.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 20),
                SolenneGlass(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  borderRadius: 20,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearch,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                    style: AppTextStyles.body(fontSize: 15),
                    decoration: InputDecoration(
                      icon: _searching
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                              ),
                            )
                          : const Icon(Icons.search_rounded, size: 19),
                      hintText: 'Search @username',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: AppTextStyles.body(
                      fontSize: 11,
                      color: AppColors.quicksand,
                    ),
                  ),
                ],
                if (query.length >= 3) ...[
                  const SizedBox(height: 18),
                  const _SectionHeading('People'),
                  const SizedBox(height: 9),
                  if (!_searching && _matches.isEmpty)
                    const _EmptyCard('No matching username found.')
                  else
                    for (final profile in _matches) ...[
                      _ProfileRow(
                        profile: profile,
                        trailing: _SearchAction(
                          profile: profile,
                          relationships: relationships,
                          currentUid: uid,
                          perform: _perform,
                        ),
                      ),
                      const SizedBox(height: 9),
                    ],
                ] else ...[
                  if (incoming.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const _SectionHeading('Requests for you'),
                    const SizedBox(height: 9),
                    for (final request in incoming) ...[
                      _ProfileRow(
                        profile: request.other(uid),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _CircleAction(
                              icon: Icons.close_rounded,
                              tooltip: 'Decline',
                              onTap: () => _perform(
                                () => ref
                                    .read(socialRepositoryProvider)
                                    .respond(request, accept: false),
                              ),
                            ),
                            const SizedBox(width: 7),
                            _CircleAction(
                              icon: Icons.check_rounded,
                              tooltip: 'Accept',
                              onTap: () => _perform(
                                () => ref
                                    .read(socialRepositoryProvider)
                                    .respond(request, accept: true),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 9),
                    ],
                  ],
                  const SizedBox(height: 20),
                  const _SectionHeading('Your friends'),
                  const SizedBox(height: 9),
                  if (friends.isEmpty)
                    const _EmptyCard(
                      'Your circle can stay small. Search a username when you are ready.',
                    )
                  else
                    for (final friendship in friends) ...[
                      _ProfileRow(
                        profile: friendship.other(uid),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                FriendActivityScreen(friendship: friendship),
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Friend options',
                          color: AppColors.royalBlue,
                          onSelected: (value) {
                            if (value == 'remove') {
                              _perform(
                                () => ref
                                    .read(socialRepositoryProvider)
                                    .removeFriend(friendship),
                              );
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'remove',
                              child: Text('Remove friend'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 9),
                    ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FriendActivityScreen extends ConsumerWidget {
  const FriendActivityScreen({super.key, required this.friendship});
  final Friendship friendship;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid ?? '';
    final friend = friendship.other(uid);
    final shares = (ref.watch(receivedSharesProvider).value ?? const [])
        .where((share) => share.owner.uid == friend.uid)
        .toList(growable: false);
    return Scaffold(
      body: SolenneBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 38),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ProfileAvatar(photoUrl: friend.photoUrl, radius: 28),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            friend.displayName,
                            style: AppTextStyles.display(fontSize: 30),
                          ),
                          Text(
                            '@${friend.username}',
                            style: AppTextStyles.mono(fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'Journals they chose to share',
                  style: AppTextStyles.body(fontSize: 18),
                ),
                const SizedBox(height: 10),
                if (shares.isEmpty)
                  const _EmptyCard('No journals have been shared with you yet.')
                else
                  for (final share in shares) ...[
                    _SharedJournalCard(share: share),
                    const SizedBox(height: 9),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SharedJournalCard extends StatelessWidget {
  const _SharedJournalCard({required this.share});
  final SharedJournalEntry share;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SharedJournalScreen(share: share),
      ),
    ),
    borderRadius: BorderRadius.circular(18),
    child: SolenneGlass(
      padding: const EdgeInsets.all(14),
      borderRadius: 18,
      child: Row(
        children: [
          Icon(
            share.entry.isWritten
                ? Icons.edit_note_rounded
                : share.entry.isAudio
                ? Icons.graphic_eq_rounded
                : Icons.play_circle_outline_rounded,
            color: AppColors.quicksand,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  share.entry.displayTitle,
                  style: AppTextStyles.body(fontSize: 15),
                ),
                Text(
                  '${DateFormat('d MMM yyyy').format(share.entry.recordedAt)} · ${share.entry.entryType} journal',
                  style: AppTextStyles.mono(fontSize: 8),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, size: 18),
        ],
      ),
    ),
  );
}

class SharedJournalScreen extends StatelessWidget {
  const SharedJournalScreen({super.key, required this.share});
  final SharedJournalEntry share;

  @override
  Widget build(BuildContext context) {
    final entry = share.entry;
    return Scaffold(
      body: SolenneBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 38),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Text(
                  entry.displayTitle,
                  style: AppTextStyles.display(fontSize: 34),
                ),
                const SizedBox(height: 4),
                Text(
                  'Shared by @${share.owner.username}',
                  style: AppTextStyles.mono(fontSize: 9),
                ),
                const SizedBox(height: 18),
                if (entry.isVideo)
                  JournalVideoPlayer(entry: entry)
                else if (entry.isWritten)
                  SolenneGlass(
                    padding: const EdgeInsets.all(18),
                    borderRadius: 20,
                    child: SelectableText(
                      entry.writtenText,
                      style: AppTextStyles.body(fontSize: 16),
                    ),
                  )
                else
                  SolenneAudioPlayer(source: entry.audioUrl),
                if (share.includeTranscript &&
                    entry.transcript.isAvailable) ...[
                  const SizedBox(height: 12),
                  SolenneGlass(
                    padding: const EdgeInsets.all(16),
                    borderRadius: 18,
                    child: SelectableText(
                      entry.transcript.text,
                      style: AppTextStyles.body(fontSize: 13),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'What surfaced',
                  style: AppTextStyles.display(fontSize: 29),
                ),
                const SizedBox(height: 10),
                for (final insight in entry.aiInsights) ...[
                  SolenneGlass(
                    padding: const EdgeInsets.all(16),
                    borderRadius: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.title,
                          style: AppTextStyles.body(fontSize: 17),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          insight.summary,
                          style: AppTextStyles.body(fontSize: 13),
                        ),
                        for (final suggestion in insight.suggestions)
                          Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Text(
                              '• $suggestion',
                              style: AppTextStyles.body(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchAction extends ConsumerWidget {
  const _SearchAction({
    required this.profile,
    required this.relationships,
    required this.currentUid,
    required this.perform,
  });
  final PublicProfile profile;
  final List<Friendship> relationships;
  final String currentUid;
  final Future<void> Function(Future<void> Function()) perform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Friendship? relationship;
    for (final item in relationships) {
      if (item.memberIds.contains(profile.uid)) relationship = item;
    }
    final label = switch (relationship?.status) {
      'accepted' => 'Friends',
      'pending' when relationship?.requesterId == currentUid => 'Requested',
      'pending' => 'Respond',
      _ => 'Add',
    };
    return TextButton(
      onPressed: label == 'Add'
          ? () => perform(
              () => ref.read(socialRepositoryProvider).sendRequest(profile),
            )
          : label == 'Requested'
          ? () => perform(
              () => ref
                  .read(socialRepositoryProvider)
                  .cancelRequest(relationship!),
            )
          : null,
      child: Text(label),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.profile,
    required this.trailing,
    this.onTap,
  });
  final PublicProfile profile;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: SolenneGlass(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      borderRadius: 18,
      child: Row(
        children: [
          ProfileAvatar(photoUrl: profile.photoUrl, radius: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: AppTextStyles.body(fontSize: 14),
                ),
                Text(
                  '@${profile.username}',
                  style: AppTextStyles.mono(fontSize: 8),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    ),
  );
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    icon: Icon(icon, color: AppColors.quicksand),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label);
  final String label;
  @override
  Widget build(BuildContext context) =>
      Text(label, style: AppTextStyles.body(fontSize: 17));
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => SolenneGlass(
    padding: const EdgeInsets.all(16),
    borderRadius: 18,
    child: Text(
      text,
      style: AppTextStyles.body(
        fontSize: 12,
        color: AppColors.shellstone.withValues(alpha: 0.68),
        fontStyle: FontStyle.italic,
      ),
    ),
  );
}
