import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/organic_background.dart';
import '../../core/widgets/solenne_button.dart';
import '../../core/widgets/solenne_card.dart';
import '../../core/widgets/solenne_visuals.dart';
import '../../services/cloudinary/cloudinary_providers.dart';
import '../journals/journal_entry.dart';
import '../journals/journal_repository.dart';
import 'local_video_controller.dart';
import 'recording_draft.dart';

class RecordingPreviewScreen extends ConsumerStatefulWidget {
  const RecordingPreviewScreen({super.key, required this.draft});

  final RecordingDraft draft;

  @override
  ConsumerState<RecordingPreviewScreen> createState() =>
      _RecordingPreviewScreenState();
}

class _RecordingPreviewScreenState
    extends ConsumerState<RecordingPreviewScreen> {
  late final VideoPlayerController _controller;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = createLocalVideoController(widget.draft.file)
      ..initialize()
          .then((_) {
            if (mounted) setState(() {});
          })
          .catchError((Object error) {
            if (mounted) setState(() => _error = error.toString());
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      context.go('/login');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final upload = await ref
          .read(cloudinaryUploadServiceProvider)
          .uploadVideo(widget.draft.file);
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final entry = JournalEntry(
        id: id,
        userId: user.uid,
        prompt: widget.draft.prompt,
        recordedAt: DateTime.now(),
        durationSeconds: widget.draft.durationSeconds,
        cloudinaryPublicId: upload.publicId,
        videoUrl: upload.secureUrl,
        thumbnailUrl: upload.thumbnailUrl,
        uploadStatus: 'saved',
        analysisStatus: 'not_started',
      );
      await ref.read(journalRepositoryProvider).saveJournal(entry);
      if (mounted) context.go('/journals');
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrganicBackground(
        showGrid: true,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
            children: [
              const SolenneSectionTitle(
                eyebrow: 'Preview',
                title: 'Review reflection',
                subtitle: 'Save it when it feels ready.',
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: AspectRatio(
                  aspectRatio: _controller.value.isInitialized
                      ? _controller.value.aspectRatio
                      : 9 / 16,
                  child: _controller.value.isInitialized
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(_controller),
                            IconButton.filled(
                              iconSize: 42,
                              onPressed: () {
                                setState(() {
                                  _controller.value.isPlaying
                                      ? _controller.pause()
                                      : _controller.play();
                                });
                              },
                              icon: Icon(
                                _controller.value.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                            ),
                          ],
                        )
                      : const ColoredBox(
                          color: AppColors.cardElevated,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                ),
              ),
              const SizedBox(height: 18),
              SolenneCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.draft.prompt,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SolenneStatusChip(
                      label: '${widget.draft.durationSeconds}s',
                      color: AppColors.aqua,
                      icon: Icons.timer_outlined,
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 18),
              SolenneButton(
                label: 'Save Reflection',
                icon: Icons.cloud_upload_rounded,
                isLoading: _saving,
                onPressed: _save,
              ),
              const SizedBox(height: 12),
              SolenneButton(
                label: 'Re-record',
                icon: Icons.refresh_rounded,
                isSecondary: true,
                onPressed: _saving ? null : () => context.go('/record'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
