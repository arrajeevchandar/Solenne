import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/auth/auth_providers.dart';
import '../../services/cloudinary/cloudinary_providers.dart';
import '../../theme/app_theme.dart';

/// A dedicated screen for editing the account display name and profile photo.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameController;
  bool _photoUploading = false;
  bool _saving = false;
  String? _photoError;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(firebaseAuthProvider).currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Only JPEG/JPG/PNG images are allowed for profile photos.
  static bool _isAllowedImage(XFile image) {
    final mime = image.mimeType?.toLowerCase();
    if (mime != null && mime.isNotEmpty) {
      return mime == 'image/jpeg' ||
          mime == 'image/jpg' ||
          mime == 'image/png';
    }
    final target = '${image.name} ${image.path}'.toLowerCase();
    return target.contains('.jpg') ||
        target.contains('.jpeg') ||
        target.contains('.png');
  }

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

    if (!_isAllowedImage(image)) {
      setState(() => _photoError = 'Please choose a JPEG, JPG, or PNG image.');
      return;
    }

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
      if (mounted) setState(() => _photoError = error.toString());
    } finally {
      if (mounted) setState(() => _photoUploading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    final name = _nameController.text.trim();

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (name != (user.displayName ?? '')) {
        await user.updateDisplayName(name.isEmpty ? null : name);
        await ref.read(firestoreProvider).collection('users').doc(user.uid).set(
          {'displayName': name, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
        await user.reload();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final photoUrl = user?.photoURL;

    return Scaffold(
      body: SolenneBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.shellstone.withValues(alpha: 0.76),
                    ),
                    const Spacer(),
                    Text(
                      'edit profile',
                      style: AppTextStyles.mono(
                        fontSize: 10,
                        color: AppColors.shellstone.withValues(alpha: 0.54),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Edit profile',
                  style: AppTextStyles.display(fontSize: 34),
                ),
                const SizedBox(height: 6),
                Text(
                  'Update your name and photo.',
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.shellstone.withValues(alpha: 0.72),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: GestureDetector(
                    onTap: _photoUploading ? null : _uploadProfilePhoto,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: AppColors.sapphire.withValues(
                            alpha: 0.32,
                          ),
                          backgroundImage:
                              photoUrl == null || photoUrl.isEmpty
                              ? null
                              : NetworkImage(photoUrl),
                          child: photoUrl == null || photoUrl.isEmpty
                              ? Icon(
                                  Icons.person_rounded,
                                  size: 44,
                                  color: AppColors.shellstone.withValues(
                                    alpha: 0.86,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.electricGold.withValues(
                                alpha: 0.95,
                              ),
                              border: Border.all(
                                color: AppColors.royalBlue.withValues(
                                  alpha: 0.9,
                                ),
                                width: 2,
                              ),
                            ),
                            child: _photoUploading
                                ? Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.8,
                                      color: AppColors.royalBlue.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.add_a_photo_rounded,
                                    size: 17,
                                    color: AppColors.royalBlue.withValues(
                                      alpha: 0.92,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Tap to change photo (JPEG or PNG)',
                    style: AppTextStyles.mono(
                      fontSize: 9,
                      color: AppColors.shellstone.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                if (_photoError != null) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      _photoError!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                        fontSize: 12,
                        color: AppColors.electricGold.withValues(alpha: 0.88),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                SolenneGlass(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  borderRadius: 20,
                  child: TextField(
                    controller: _nameController,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.words,
                    style: AppTextStyles.body(
                      fontSize: 16,
                      color: AppColors.swanWing.withValues(alpha: 0.92),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Display name',
                      hintText: 'Your name',
                      labelStyle: AppTextStyles.mono(
                        fontSize: 10,
                        color: AppColors.quicksand.withValues(alpha: 0.72),
                      ),
                      hintStyle: AppTextStyles.body(
                        fontSize: 14,
                        color: AppColors.shellstone.withValues(alpha: 0.42),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SolenneGlass(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  borderRadius: 20,
                  child: Row(
                    children: [
                      Icon(
                        Icons.mail_outline_rounded,
                        size: 16,
                        color: AppColors.shellstone.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          user?.email ?? 'No email on file',
                          style: AppTextStyles.body(
                            fontSize: 14,
                            color: AppColors.shellstone.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      Text(
                        'read only',
                        style: AppTextStyles.mono(
                          fontSize: 8,
                          color: AppColors.shellstone.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: AppTextStyles.body(
                      fontSize: 12,
                      color: AppColors.electricGold.withValues(alpha: 0.9),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                GestureDetector(
                  onTap: _saving ? null : _save,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.quicksand.withValues(alpha: 0.45),
                      ),
                      color: AppColors.quicksand.withValues(alpha: 0.18),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _saving
                              ? Icons.hourglass_top_rounded
                              : Icons.check_rounded,
                          size: 18,
                          color: AppColors.quicksand.withValues(alpha: 0.92),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _saving ? 'Saving' : 'Save changes',
                          style: AppTextStyles.mono(
                            fontSize: 11,
                            color: AppColors.quicksand.withValues(alpha: 0.92),
                          ),
                        ),
                      ],
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
