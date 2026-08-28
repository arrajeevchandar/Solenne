import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_providers.dart';
import '../../features/auth/legal_documents.dart';
import '../../core/errors/user_error_message.dart';
import '../../theme/app_theme.dart';

class LegalPrivacyScreen extends ConsumerStatefulWidget {
  const LegalPrivacyScreen({super.key});

  @override
  ConsumerState<LegalPrivacyScreen> createState() => _LegalPrivacyScreenState();
}

class _LegalPrivacyScreenState extends ConsumerState<LegalPrivacyScreen> {
  bool _saving = false;
  String? _error;

  Future<void> _setConsent(bool value) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).setAiConsent(value);
      ref.invalidate(userProfileProvider);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = userErrorMessage(
            error,
            fallback: 'Your consent preference could not be updated.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
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
                    Text(
                      'LEGAL & PRIVACY',
                      style: AppTextStyles.mono(
                        fontSize: 9,
                        color: AppColors.shellstone.withValues(alpha: 0.54),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Your choices',
                  style: AppTextStyles.display(fontSize: 34),
                ),
                const SizedBox(height: 6),
                Text(
                  'Clear records of what Solenne processes and why.',
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.shellstone.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 20),
                SolenneGlass(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 20,
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Future AI analysis',
                              style: AppTextStyles.body(fontSize: 15),
                            ),
                            Text(
                              'Turning this off blocks new analysis and journal sharing. Existing data is not deleted.',
                              style: AppTextStyles.body(
                                fontSize: 11,
                                color: AppColors.shellstone.withValues(
                                  alpha: 0.64,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: profile?.aiConsentGranted ?? true,
                        onChanged: _saving ? null : _setConsent,
                        activeTrackColor: AppColors.quicksand.withValues(
                          alpha: 0.58,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: AppTextStyles.body(fontSize: 12)),
                ],
                const SizedBox(height: 18),
                for (final kind in LegalDocumentKind.values) ...[
                  _DocumentCard(kind: kind),
                  const SizedBox(height: 10),
                ],
                if (!LegalConfig.isProductionReady)
                  Text(
                    'Prototype legal operator details must be replaced before release.',
                    style: AppTextStyles.mono(
                      fontSize: 8,
                      color: AppColors.quicksand.withValues(alpha: 0.78),
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

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.kind});
  final LegalDocumentKind kind;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: const EdgeInsets.symmetric(horizontal: 14),
    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    collapsedShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: AppColors.shellstone.withValues(alpha: 0.12)),
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: AppColors.quicksand.withValues(alpha: 0.24)),
    ),
    title: Text(kind.title, style: AppTextStyles.body(fontSize: 15)),
    subtitle: Text(
      'Version ${kind.version}',
      style: AppTextStyles.mono(
        fontSize: 8,
        color: AppColors.shellstone.withValues(alpha: 0.48),
      ),
    ),
    children: [
      SelectableText(
        kind.body.trim(),
        style: AppTextStyles.body(
          fontSize: 12,
          color: AppColors.shellstone.withValues(alpha: 0.78),
        ),
      ),
    ],
  );
}
