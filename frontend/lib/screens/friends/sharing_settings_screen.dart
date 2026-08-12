import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class SharingSettingsScreen extends StatefulWidget {
  const SharingSettingsScreen({super.key});

  @override
  State<SharingSettingsScreen> createState() => _SharingSettingsScreenState();
}

class _SharingSettingsScreenState extends State<SharingSettingsScreen> {
  bool _friendsCanViewSharedEntries = false;
  bool _allowCheckInPrompts = false;
  final _entries = <_ShareableEntry>[
    _ShareableEntry('A quieter morning', 'Today, 8 min'),
    _ShareableEntry('Sleep and timing', 'Yesterday, 6 min'),
    _ShareableEntry('Decision I kept avoiding', '2 days ago, 11 min'),
  ];

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
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.shellstone.withValues(alpha: 0.78),
                    ),
                    const Spacer(),
                    Text(
                      'SHARING',
                      style: AppTextStyles.mono(
                        fontSize: 10,
                        color: AppColors.shellstone.withValues(alpha: 0.52),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Your sharing circle',
                  style: AppTextStyles.display(fontSize: 34),
                ),
                const SizedBox(height: 5),
                Text(
                  'Nothing is shared until you turn it on and select an entry.',
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.shellstone.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 22),
                _SharingSwitchCard(
                  icon: Icons.menu_book_outlined,
                  title: 'Share selected journals',
                  detail:
                      'Friends can only open entries you explicitly choose below.',
                  value: _friendsCanViewSharedEntries,
                  onChanged: (value) =>
                      setState(() => _friendsCanViewSharedEntries = value),
                ),
                const SizedBox(height: 12),
                _SharingSwitchCard(
                  icon: Icons.favorite_outline_rounded,
                  title: 'Allow check-in prompts',
                  detail:
                      'A trusted friend can be prompted to check in if you opt in and a future safety workflow identifies a concern.',
                  value: _allowCheckInPrompts,
                  onChanged: (value) =>
                      setState(() => _allowCheckInPrompts = value),
                ),
                const SizedBox(height: 22),
                Text(
                  'Entries you choose to share',
                  style: AppTextStyles.body(
                    fontSize: 18,
                    color: AppColors.swanWing.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: 10),
                for (final entry in _entries) ...[
                  _EntryPermissionRow(
                    entry: entry,
                    enabled: _friendsCanViewSharedEntries,
                    onChanged: (value) => setState(() => entry.shared = value),
                  ),
                  const SizedBox(height: 9),
                ],
                const SizedBox(height: 16),
                SolenneGlass(
                  padding: const EdgeInsets.all(15),
                  borderRadius: 18,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.privacy_tip_outlined,
                        size: 20,
                        color: AppColors.quicksand.withValues(alpha: 0.78),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          'Friends never see your private analyses, full timeline, or raw wellbeing scores. You can turn any permission off at any time.',
                          style: AppTextStyles.body(
                            fontSize: 11,
                            color: AppColors.shellstone.withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                    ],
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

class _SharingSwitchCard extends StatelessWidget {
  const _SharingSwitchCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SolenneGlass(
    padding: const EdgeInsets.fromLTRB(15, 14, 11, 14),
    borderRadius: 18,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.quicksand.withValues(alpha: 0.78),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.body(fontSize: 15)),
              const SizedBox(height: 3),
              Text(
                detail,
                style: AppTextStyles.body(
                  fontSize: 11,
                  color: AppColors.shellstone.withValues(alpha: 0.66),
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppColors.quicksand.withValues(alpha: 0.58),
          activeThumbColor: AppColors.swanWing,
        ),
      ],
    ),
  );
}

class _EntryPermissionRow extends StatelessWidget {
  const _EntryPermissionRow({
    required this.entry,
    required this.enabled,
    required this.onChanged,
  });

  final _ShareableEntry entry;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1 : 0.48,
    child: SolenneGlass(
      padding: const EdgeInsets.fromLTRB(15, 12, 10, 12),
      borderRadius: 16,
      child: Row(
        children: [
          Icon(
            entry.shared ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
            size: 18,
            color: AppColors.quicksand.withValues(alpha: 0.74),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, style: AppTextStyles.body(fontSize: 14)),
                Text(
                  entry.detail,
                  style: AppTextStyles.mono(
                    fontSize: 8,
                    color: AppColors.shellstone.withValues(alpha: 0.52),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: entry.shared,
            onChanged: enabled ? onChanged : null,
            activeTrackColor: AppColors.quicksand.withValues(alpha: 0.58),
            activeThumbColor: AppColors.swanWing,
          ),
        ],
      ),
    ),
  );
}

class _ShareableEntry {
  _ShareableEntry(this.title, this.detail);

  final String title;
  final String detail;
  bool shared = false;
}
