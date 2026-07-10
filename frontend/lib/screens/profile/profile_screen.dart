import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../routing/fade_through_route.dart';
import '../../services/cloudinary/cloudinary_providers.dart';
import '../../theme/app_theme.dart';
import '../../features/auth/auth_providers.dart';
import '../auth/auth_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _voice = 'Observational';
  bool _photoUploading = false;
  String? _photoError;

  Future<void> _uploadProfilePhoto() async {
    if (_photoUploading) return;
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
      maxWidth: 1200,
    );
    if (image == null) return;

    setState(() {
      _photoUploading = true;
      _photoError = null;
    });

    try {
      final upload = await ref
          .read(cloudinaryUploadServiceProvider)
          .uploadImage(image);
      await user.updatePhotoURL(upload.secureUrl);
      await ref.read(firestoreProvider).collection('users').doc(user.uid).set({
        'photoUrl': upload.secureUrl,
        'photoPublicId': upload.publicId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await user.reload();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        setState(() => _photoError = error.toString());
      }
    } finally {
      if (mounted) setState(() => _photoUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CosmicPage(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 106),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Profile',
                      style: AppTextStyles.display(fontSize: 36),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Minimal controls. Clear trust.',
                style: AppTextStyles.body(
                  fontSize: 14,
                  color: AppColors.shellstone.withValues(alpha: 0.72),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 24),
              _Glass(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Account'),
                    const SizedBox(height: 14),
                    _ProfileSummary(
                      uploading: _photoUploading,
                      onUploadPhoto: _uploadProfilePhoto,
                    ),
                    if (_photoError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _photoError!,
                        style: AppTextStyles.body(
                          fontSize: 12,
                          color: AppColors.electricGold.withValues(alpha: 0.88),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const _SettingsRow(
                      icon: Icons.edit_rounded,
                      label: 'Edit profile',
                      detail: 'Username, name, and photo',
                    ),
                    const SizedBox(height: 12),
                    _SettingsRow(
                      icon: Icons.logout_rounded,
                      label: 'Log out',
                      detail: 'Return to sign in',
                      isDestructive: true,
                      onTap: () async {
                        await ref.read(authRepositoryProvider).signOut();
                        if (!context.mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          fadeThroughRoute(const AuthScreen()),
                          (_) => false,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Glass(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Voice'),
                    const SizedBox(height: 12),
                    _VoiceOption(
                      label: 'Observational',
                      text: 'Just notices, rarely offers warmth.',
                      selected: _voice == 'Observational',
                      onTap: () => setState(() => _voice = 'Observational'),
                    ),
                    _VoiceOption(
                      label: 'Warm',
                      text: 'More relational, uses your name more.',
                      selected: _voice == 'Warm',
                      onTap: () => setState(() => _voice = 'Warm'),
                    ),
                    _VoiceOption(
                      label: 'Sparse',
                      text: 'Almost no generated text, minimal AI voice.',
                      selected: _voice == 'Sparse',
                      onTap: () => setState(() => _voice = 'Sparse'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Glass(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Baseline reset'),
                    const SizedBox(height: 10),
                    Text(
                      'If something major has changed, Solenne can mark a new baseline beginning now. Your history stays preserved and labeled before July 2026.',
                      style: AppTextStyles.body(
                        fontSize: 14,
                        color: AppColors.shellstone.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _SoftButton(label: 'Mark a new baseline'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Glass(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Privacy'),
                    const SizedBox(height: 10),
                    Text(
                      'Solenne analyzes voice, words, timing, and recurring themes to build your personal baseline. Processing happens on-device where possible. Your entries are not shared, not benchmarked against other users, and not sold.',
                      style: AppTextStyles.body(
                        fontSize: 14,
                        color: AppColors.shellstone.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Glass(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _SectionTitle('Entry archive'),
                    SizedBox(height: 10),
                    _ArchiveRow(
                      icon: Icons.audio_file_rounded,
                      label: 'Export audio files',
                    ),
                    SizedBox(height: 10),
                    _ArchiveRow(
                      icon: Icons.description_rounded,
                      label: 'Export text transcripts',
                    ),
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

class _ProfileSummary extends ConsumerWidget {
  const _ProfileSummary({required this.uploading, required this.onUploadPhoto});

  final bool uploading;
  final VoidCallback onUploadPhoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final photoUrl = user?.photoURL;
    return SolenneGlass(
      padding: const EdgeInsets.all(14),
      borderRadius: 20,
      child: Row(
        children: [
          GestureDetector(
            onTap: uploading ? null : onUploadPhoto,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.sapphire.withValues(alpha: 0.32),
                  backgroundImage: photoUrl == null || photoUrl.isEmpty
                      ? null
                      : NetworkImage(photoUrl),
                  child: photoUrl == null || photoUrl.isEmpty
                      ? Icon(
                          Icons.person_rounded,
                          color: AppColors.shellstone.withValues(alpha: 0.86),
                        )
                      : null,
                ),
                Positioned(
                  right: -3,
                  bottom: -3,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.electricGold.withValues(alpha: 0.95),
                      border: Border.all(
                        color: AppColors.royalBlue.withValues(alpha: 0.9),
                      ),
                    ),
                    child: uploading
                        ? Padding(
                            padding: const EdgeInsets.all(5),
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6,
                              color: AppColors.royalBlue.withValues(alpha: 0.9),
                            ),
                          )
                        : Icon(
                            Icons.add_a_photo_rounded,
                            size: 12,
                            color: AppColors.royalBlue.withValues(alpha: 0.92),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'username',
                  style: AppTextStyles.body(
                    fontSize: 16,
                    color: AppColors.swanWing.withValues(alpha: 0.92),
                  ),
                ),
                Text(
                  user?.email ?? 'username@email.com',
                  style: AppTextStyles.mono(
                    fontSize: 9,
                    color: AppColors.shellstone.withValues(alpha: 0.54),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: uploading ? null : onUploadPhoto,
                  child: Text(
                    uploading ? 'uploading photo...' : 'upload profile photo',
                    style: AppTextStyles.mono(
                      fontSize: 9,
                      color: AppColors.electricGold.withValues(alpha: 0.78),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final bool isDestructive;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.detail,
    this.isDestructive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? AppColors.quicksand.withValues(alpha: 0.86)
        : AppColors.shellstone.withValues(alpha: 0.86);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.body(fontSize: 14, color: color),
                ),
                Text(
                  detail,
                  style: AppTextStyles.mono(
                    fontSize: 9,
                    color: AppColors.shellstone.withValues(alpha: 0.48),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.shellstone.withValues(alpha: 0.42),
          ),
        ],
      ),
    );
  }
}

class _VoiceOption extends StatelessWidget {
  final String label;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _VoiceOption({
    required this.label,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.sapphire.withValues(alpha: 0.48)
                : AppColors.shellstone.withValues(alpha: 0.13),
          ),
          color: selected
              ? AppColors.sapphire.withValues(alpha: 0.22)
              : AppColors.royalBlue.withValues(alpha: 0.16),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected
                  ? AppColors.quicksand.withValues(alpha: 0.82)
                  : AppColors.shellstone.withValues(alpha: 0.52),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.body(
                      fontSize: 14,
                      color: AppColors.swanWing.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text,
                    style: AppTextStyles.body(
                      fontSize: 12,
                      color: AppColors.shellstone.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ArchiveRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColors.quicksand.withValues(alpha: 0.72),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.body(
              fontSize: 14,
              color: AppColors.shellstone.withValues(alpha: 0.82),
            ),
          ),
        ),
        Icon(
          Icons.arrow_forward_rounded,
          size: 17,
          color: AppColors.shellstone.withValues(alpha: 0.44),
        ),
      ],
    );
  }
}

class _SoftButton extends StatelessWidget {
  final String label;

  const _SoftButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.sapphire.withValues(alpha: 0.2),
        border: Border.all(color: AppColors.shellstone.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: AppTextStyles.mono(
          fontSize: 10,
          color: AppColors.quicksand.withValues(alpha: 0.78),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.body(
        fontSize: 18,
        color: AppColors.swanWing.withValues(alpha: 0.94),
      ),
    );
  }
}

class _CosmicPage extends StatelessWidget {
  final Widget child;

  const _CosmicPage({required this.child});

  @override
  Widget build(BuildContext context) {
    return SolenneBackground(child: child);
  }
}

class _Glass extends StatelessWidget {
  final Widget child;

  const _Glass({required this.child});

  @override
  Widget build(BuildContext context) {
    return SolenneGlass(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      child: child,
    );
  }
}
