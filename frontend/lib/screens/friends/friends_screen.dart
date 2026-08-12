import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchController = TextEditingController();
  final _sentRequests = <String>{};
  final _friends = <_FriendProfile>[
    _FriendProfile('Meera Shah', 'meerashah', Icons.wb_twilight_rounded),
    _FriendProfile('Aarav Sen', 'aarav_sen', Icons.auto_awesome_rounded),
  ];
  final _incomingRequests = <_FriendProfile>[
    _FriendProfile('Tara Menon', 'tara_m', Icons.nights_stay_outlined),
    _FriendProfile('Kabir Rao', 'kabir.rao', Icons.bubble_chart_outlined),
  ];

  static const _discover = [
    _FriendProfile('Maya Kapoor', 'mayak', Icons.local_florist_outlined),
    _FriendProfile('Riya Das', 'riya.reflects', Icons.waves_rounded),
    _FriendProfile('Dev Iyer', 'devwrites', Icons.light_mode_outlined),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase().replaceFirst(
      '@',
      '',
    );
    final matches = _discover
        .where(
          (profile) =>
              query.isNotEmpty &&
              (profile.username.contains(query) ||
                  profile.name.toLowerCase().contains(query)),
        )
        .toList(growable: false);
    return Scaffold(
      body: SolenneBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
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
                        color: AppColors.shellstone.withValues(alpha: 0.78),
                      )
                    else
                      const SizedBox(width: 12),
                    const Spacer(),
                    Text(
                      'FRIENDS',
                      style: AppTextStyles.mono(
                        fontSize: 10,
                        color: AppColors.shellstone.withValues(alpha: 0.52),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Your circle', style: AppTextStyles.display(fontSize: 34)),
                const SizedBox(height: 5),
                Text(
                  'Share connection, never your private entries.',
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.shellstone.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 22),
                SolenneGlass(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  borderRadius: 20,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                    style: AppTextStyles.body(fontSize: 15),
                    decoration: InputDecoration(
                      icon: Icon(
                        Icons.search_rounded,
                        size: 19,
                        color: AppColors.quicksand.withValues(alpha: 0.74),
                      ),
                      hintText: 'Search by name or @username',
                      hintStyle: AppTextStyles.body(
                        fontSize: 13,
                        color: AppColors.shellstone.withValues(alpha: 0.42),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (query.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionHeading('People'),
                  const SizedBox(height: 9),
                  if (matches.isEmpty)
                    _EmptySearch(query: query)
                  else
                    for (final profile in matches) ...[
                      _PersonRow(
                        profile: profile,
                        action: _sentRequests.contains(profile.username)
                            ? _FriendAction.requested
                            : _FriendAction.add,
                        onAction: () => setState(() {
                          if (_sentRequests.contains(profile.username)) {
                            _sentRequests.remove(profile.username);
                          } else {
                            _sentRequests.add(profile.username);
                          }
                        }),
                      ),
                      const SizedBox(height: 9),
                    ],
                ],
                if (query.isEmpty && _incomingRequests.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionHeading('Requests for you'),
                  const SizedBox(height: 9),
                  for (final profile in _incomingRequests.toList()) ...[
                    _PersonRow(
                      profile: profile,
                      action: _FriendAction.respond,
                      onAccept: () => setState(() {
                        _incomingRequests.remove(profile);
                        _friends.add(profile);
                      }),
                      onDecline: () =>
                          setState(() => _incomingRequests.remove(profile)),
                    ),
                    const SizedBox(height: 9),
                  ],
                ],
                if (query.isEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionHeading('Your friends'),
                  const SizedBox(height: 9),
                  if (_friends.isEmpty)
                    const _FriendsEmptyState()
                  else
                    for (final profile in _friends) ...[
                      _PersonRow(
                        profile: profile,
                        action: _FriendAction.friend,
                        onRowTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                _FriendActivityScreen(profile: profile),
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                    ],
                ],
                const SizedBox(height: 16),
                Text(
                  'Friendship tools are in preview. Requests are only stored on this device until secure syncing is added.',
                  style: AppTextStyles.body(
                    fontSize: 10,
                    color: AppColors.shellstone.withValues(alpha: 0.48),
                    fontStyle: FontStyle.italic,
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: AppTextStyles.body(
      fontSize: 17,
      color: AppColors.swanWing.withValues(alpha: 0.92),
    ),
  );
}

enum _FriendAction { add, requested, respond, friend }

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.profile,
    required this.action,
    this.onAction,
    this.onAccept,
    this.onDecline,
    this.onRowTap,
  });

  final _FriendProfile profile;
  final _FriendAction action;
  final VoidCallback? onAction;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onRowTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onRowTap,
      borderRadius: BorderRadius.circular(18),
      child: SolenneGlass(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        borderRadius: 18,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.sapphire.withValues(alpha: 0.28),
                border: Border.all(
                  color: AppColors.shellstone.withValues(alpha: 0.12),
                ),
              ),
              child: Icon(profile.icon, size: 19, color: AppColors.quicksand),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.name, style: AppTextStyles.body(fontSize: 14)),
                  const SizedBox(height: 1),
                  Text(
                    '@${profile.username}',
                    style: AppTextStyles.mono(
                      fontSize: 8,
                      color: AppColors.shellstone.withValues(alpha: 0.54),
                    ),
                  ),
                ],
              ),
            ),
            if (action == _FriendAction.respond) ...[
              _RoundAction(
                icon: Icons.close_rounded,
                tooltip: 'Decline request',
                onTap: onDecline!,
                quiet: true,
              ),
              const SizedBox(width: 8),
              _RoundAction(
                icon: Icons.check_rounded,
                tooltip: 'Accept request',
                onTap: onAccept!,
              ),
            ] else if (action == _FriendAction.friend)
              Icon(
                Icons.people_alt_rounded,
                size: 19,
                color: AppColors.quicksand.withValues(alpha: 0.74),
              )
            else
              _TextAction(
                label: action == _FriendAction.add ? 'Add' : 'Requested',
                onTap: onAction!,
                quiet: action == _FriendAction.requested,
              ),
          ],
        ),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    required this.onTap,
    required this.quiet,
  });

  final String label;
  final VoidCallback onTap;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: quiet
              ? AppColors.sapphire.withValues(alpha: 0.16)
              : AppColors.quicksand.withValues(alpha: 0.16),
          border: Border.all(
            color: quiet
                ? AppColors.shellstone.withValues(alpha: 0.14)
                : AppColors.quicksand.withValues(alpha: 0.34),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.mono(
            fontSize: 8,
            color: quiet
                ? AppColors.shellstone.withValues(alpha: 0.62)
                : AppColors.quicksand,
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.quiet = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool quiet;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: quiet
              ? AppColors.sapphire.withValues(alpha: 0.16)
              : AppColors.quicksand.withValues(alpha: 0.16),
        ),
        child: Icon(
          icon,
          size: 17,
          color: quiet
              ? AppColors.shellstone.withValues(alpha: 0.7)
              : AppColors.quicksand,
        ),
      ),
    ),
  );
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) => SolenneGlass(
    padding: const EdgeInsets.all(16),
    borderRadius: 18,
    child: Text(
      'No preview user found for @$query.',
      style: AppTextStyles.body(
        fontSize: 12,
        color: AppColors.shellstone.withValues(alpha: 0.68),
        fontStyle: FontStyle.italic,
      ),
    ),
  );
}

class _FriendsEmptyState extends StatelessWidget {
  const _FriendsEmptyState();

  @override
  Widget build(BuildContext context) => SolenneGlass(
    padding: const EdgeInsets.all(16),
    borderRadius: 18,
    child: Text(
      'Your circle can stay small. Search a username when you are ready to connect.',
      style: AppTextStyles.body(
        fontSize: 12,
        color: AppColors.shellstone.withValues(alpha: 0.68),
        fontStyle: FontStyle.italic,
      ),
    ),
  );
}

class _FriendProfile {
  const _FriendProfile(this.name, this.username, this.icon);

  final String name;
  final String username;
  final IconData icon;
}

class _FriendActivityScreen extends StatelessWidget {
  const _FriendActivityScreen({required this.profile});

  final _FriendProfile profile;

  @override
  Widget build(BuildContext context) {
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
                      tooltip: 'Back to friends',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.shellstone.withValues(alpha: 0.78),
                    ),
                    const Spacer(),
                    Text(
                      'SHARED WITH YOU',
                      style: AppTextStyles.mono(
                        fontSize: 9,
                        color: AppColors.shellstone.withValues(alpha: 0.52),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.sapphire.withValues(alpha: 0.3),
                      ),
                      child: Icon(
                        profile.icon,
                        color: AppColors.quicksand,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            style: AppTextStyles.display(fontSize: 30),
                          ),
                          Text(
                            '@${profile.username}',
                            style: AppTextStyles.mono(
                              fontSize: 9,
                              color: AppColors.shellstone.withValues(
                                alpha: 0.54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _CheckInPrompt(friendName: profile.name.split(' ').first),
                const SizedBox(height: 20),
                Text(
                  'Journals they chose to share',
                  style: AppTextStyles.body(
                    fontSize: 18,
                    color: AppColors.swanWing.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: 10),
                const _SharedJournalCard(
                  title: 'Making some space',
                  detail: 'Shared today · Voice journal',
                  note: 'A short reflection was shared with you.',
                ),
                const SizedBox(height: 9),
                const _SharedJournalCard(
                  title: 'Slow Sunday',
                  detail: 'Shared 3 days ago · Written journal',
                  note: 'A short reflection was shared with you.',
                ),
                const SizedBox(height: 16),
                Text(
                  'Only ${profile.name.split(' ').first} can decide what appears here. Their private journals and analytics remain private.',
                  style: AppTextStyles.body(
                    fontSize: 10,
                    color: AppColors.shellstone.withValues(alpha: 0.5),
                    fontStyle: FontStyle.italic,
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

class _CheckInPrompt extends StatelessWidget {
  const _CheckInPrompt({required this.friendName});

  final String friendName;

  @override
  Widget build(BuildContext context) => SolenneGlass(
    padding: const EdgeInsets.all(16),
    borderRadius: 20,
    tint: AppColors.sapphire,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.quicksand.withValues(alpha: 0.12),
              ),
              child: Icon(
                Icons.favorite_outline_rounded,
                size: 19,
                color: AppColors.quicksand.withValues(alpha: 0.84),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                'A gentle check-in',
                style: AppTextStyles.body(fontSize: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '$friendName chose to allow a trusted friend to receive a check-in prompt. Consider sending a simple message today.',
          style: AppTextStyles.body(
            fontSize: 12,
            color: AppColors.shellstone.withValues(alpha: 0.74),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Check-in message flow will be connected next.'),
            ),
          ),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
          label: const Text('Send a check-in'),
          style: TextButton.styleFrom(foregroundColor: AppColors.quicksand),
        ),
        Text(
          'This is not a diagnosis or emergency assessment. If you believe someone is in immediate danger, contact local emergency services or a crisis resource.',
          style: AppTextStyles.body(
            fontSize: 9,
            color: AppColors.shellstone.withValues(alpha: 0.48),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    ),
  );
}

class _SharedJournalCard extends StatelessWidget {
  const _SharedJournalCard({
    required this.title,
    required this.detail,
    required this.note,
  });

  final String title;
  final String detail;
  final String note;

  @override
  Widget build(BuildContext context) => SolenneGlass(
    padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
    borderRadius: 18,
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.sapphire.withValues(alpha: 0.24),
          ),
          child: Icon(
            Icons.lock_open_rounded,
            size: 19,
            color: AppColors.quicksand.withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.body(fontSize: 15)),
              const SizedBox(height: 1),
              Text(
                detail,
                style: AppTextStyles.mono(
                  fontSize: 8,
                  color: AppColors.shellstone.withValues(alpha: 0.52),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                note,
                style: AppTextStyles.body(
                  fontSize: 10,
                  color: AppColors.shellstone.withValues(alpha: 0.66),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
