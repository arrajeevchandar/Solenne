import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../features/journals/journal_entry.dart';
import '../../features/journals/journal_repository.dart';
import '../../features/recording/local_video_controller.dart';
import '../../features/recording/recording_draft.dart';
import '../../routing/fade_through_route.dart';
import '../../services/cloudinary/cloudinary_providers.dart';
import '../../services/cloudinary/cloudinary_upload_service.dart';
import '../../theme/app_theme.dart';
import '../app_shell.dart';
import 'entry_saved_screen.dart';
import 'recording_screen.dart';

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
  late final TextEditingController _titleController;
  late final String _journalId;
  late final DateTime _recordedAt;
  CloudinaryUploadResult? _uploadedVideo;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _journalId = DateTime.now().microsecondsSinceEpoch.toString();
    _recordedAt = DateTime.now();
    _controller = createLocalVideoController(widget.draft.file)
      ..initialize()
          .then((_) {
            if (mounted) setState(() {});
          })
          .catchError((Object error) {
            if (mounted) setState(() => _error = error.toString());
          });
    // Keep the scrubber position and play/pause icon in sync with playback.
    _controller.addListener(_onPlaybackTick);
    _titleController = TextEditingController();
  }

  void _onPlaybackTick() {
    if (mounted) setState(() {});
  }

  /// Discards this recording without saving and returns to the home screen.
  void _discard() {
    if (_saving) return;
    Navigator.of(context).pushAndRemoveUntil(
      fadeThroughRoute(const AppShell()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlaybackTick);
    _controller.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = 'Please log in again before saving.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      debugPrint(
        '[Solenne] Starting Cloudinary upload: '
        'name=${widget.draft.file.name}, duration=${widget.draft.durationSeconds}s',
      );
      final upload =
          _uploadedVideo ??
          await ref
              .read(cloudinaryUploadServiceProvider)
              .uploadVideo(widget.draft.file);
      _uploadedVideo = upload;
      debugPrint(
        '[Solenne] Cloudinary upload complete: '
        'publicId=${upload.publicId}, url=${upload.secureUrl}',
      );
      final entry = JournalEntry(
        id: _journalId,
        userId: user.uid,
        prompt: widget.draft.prompt,
        recordedAt: _recordedAt,
        durationSeconds: widget.draft.durationSeconds,
        cloudinaryPublicId: upload.publicId,
        videoUrl: upload.secureUrl,
        thumbnailUrl: upload.thumbnailUrl,
        uploadStatus: 'saved',
        analysisStatus: 'queued',
        analysisStep: 'queued',
        analysisVersion: JournalRepository.analysisVersion,
        title: _titleController.text.trim(),
      );
      debugPrint(
        '[Solenne] Saving journal metadata and analysis job: id=$_journalId',
      );
      await ref.read(journalRepositoryProvider).saveJournal(entry);
      debugPrint('[Solenne] Journal metadata saved: id=$_journalId');
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => EntrySavedScreen(entryId: _journalId),
        ),
        (_) => false,
      );
    } catch (error) {
      debugPrint('[Solenne] Save entry failed: $error');
      setState(
        () => _error =
            'Could not save this entry yet. Check your connection and Cloudinary setup, then try again.\n\n$error',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SolenneBackground(
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _PreviewSkyPainter())),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _saving
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16,
                            color: AppColors.shellstone.withValues(alpha: 0.7),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'review room',
                          style: AppTextStyles.mono(
                            fontSize: 10,
                            color: AppColors.shellstone.withValues(alpha: 0.54),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Save this entry?',
                      style: AppTextStyles.display(fontSize: 34),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Watch it back once. Keep it if it feels true enough.',
                      style: AppTextStyles.body(
                        fontSize: 14,
                        color: AppColors.shellstone.withValues(alpha: 0.72),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _Glass(
                      padding: const EdgeInsets.all(10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: AspectRatio(
                          aspectRatio: _controller.value.isInitialized
                              ? _controller.value.aspectRatio
                              : 9 / 16,
                          child: _controller.value.isInitialized
                              ? Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    VideoPlayer(_controller),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _controller.value.isPlaying
                                              ? _controller.pause()
                                              : _controller.play();
                                        });
                                      },
                                      child: Container(
                                        width: 62,
                                        height: 62,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.quicksand.withValues(
                                            alpha: 0.82,
                                          ),
                                        ),
                                        child: Icon(
                                          _controller.value.isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          color: AppColors.royalBlue,
                                          size: 34,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ColoredBox(
                                  color: AppColors.royalBlue.withValues(
                                    alpha: 0.34,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.quicksand,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    if (_controller.value.isInitialized) ...[
                      const SizedBox(height: 12),
                      _PlaybackScrubber(controller: _controller),
                    ],
                    const SizedBox(height: 16),
                    _Glass(
                      child: TextField(
                        controller: _titleController,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.sentences,
                        style: AppTextStyles.body(
                          fontSize: 16,
                          color: AppColors.swanWing.withValues(alpha: 0.9),
                        ),
                        decoration: InputDecoration(
                          labelText: 'Name this recording',
                          hintText: 'e.g. A quieter morning',
                          labelStyle: AppTextStyles.mono(
                            fontSize: 10,
                            color: AppColors.quicksand.withValues(alpha: 0.72),
                          ),
                          hintStyle: AppTextStyles.body(
                            fontSize: 14,
                            color: AppColors.shellstone.withValues(alpha: 0.42),
                            fontStyle: FontStyle.italic,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Glass(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.draft.prompt,
                            style: AppTextStyles.body(
                              fontSize: 16,
                              color: AppColors.swanWing.withValues(alpha: 0.9),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${widget.draft.durationSeconds}s',
                            style: AppTextStyles.mono(
                              fontSize: 10,
                              color: AppColors.shellstone.withValues(
                                alpha: 0.62,
                              ),
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
                          color: AppColors.quicksand.withValues(alpha: 0.9),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _ActionButton(
                      label: _saving ? 'Saving' : 'Save entry',
                      icon: Icons.cloud_upload_rounded,
                      onTap: _saving ? null : _save,
                    ),
                    const SizedBox(height: 12),
                    _ActionButton(
                      label: 'Record again',
                      icon: Icons.refresh_rounded,
                      onTap: _saving
                          ? null
                          : () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute<void>(
                                builder: (_) => const RecordingScreen(),
                              ),
                            ),
                      quiet: true,
                    ),
                    const SizedBox(height: 12),
                    _ActionButton(
                      label: "No, don't save",
                      icon: Icons.close_rounded,
                      onTap: _saving ? null : _discard,
                      quiet: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.quiet = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: quiet
                ? AppColors.shellstone.withValues(alpha: 0.18)
                : AppColors.quicksand.withValues(alpha: 0.45),
          ),
          color: quiet
              ? AppColors.royalBlue.withValues(alpha: 0.2)
              : AppColors.quicksand.withValues(alpha: 0.18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: quiet
                  ? AppColors.shellstone.withValues(alpha: 0.72)
                  : AppColors.quicksand.withValues(alpha: 0.92),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppTextStyles.mono(
                fontSize: 11,
                color: quiet
                    ? AppColors.shellstone.withValues(alpha: 0.72)
                    : AppColors.quicksand.withValues(alpha: 0.92),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackScrubber extends StatelessWidget {
  const _PlaybackScrubber({required this.controller});

  final VideoPlayerController controller;

  static String _clock(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString();
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _skip(Duration offset) {
    final total = controller.value.duration;
    var target = controller.value.position + offset;
    if (target < Duration.zero) target = Duration.zero;
    if (target > total) target = total;
    controller.seekTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    return Column(
      children: [
        Row(
          children: [
            _SkipButton(
              icon: Icons.replay_10_rounded,
              onTap: () => _skip(const Duration(seconds: -10)),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: AppColors.quicksand.withValues(alpha: 0.9),
                  inactiveTrackColor: AppColors.shellstone.withValues(
                    alpha: 0.24,
                  ),
                  thumbColor: AppColors.quicksand,
                  overlayColor: AppColors.quicksand.withValues(alpha: 0.18),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                ),
                child: Slider(
                  min: 0,
                  max: value.duration.inMilliseconds
                      .clamp(1, 1 << 31)
                      .toDouble(),
                  value: value.position.inMilliseconds
                      .clamp(0, value.duration.inMilliseconds)
                      .toDouble(),
                  onChanged: (millis) {
                    controller.seekTo(Duration(milliseconds: millis.round()));
                  },
                ),
              ),
            ),
            _SkipButton(
              icon: Icons.forward_10_rounded,
              onTap: () => _skip(const Duration(seconds: 10)),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _clock(value.position),
                style: AppTextStyles.mono(
                  fontSize: 10,
                  color: AppColors.shellstone.withValues(alpha: 0.66),
                ),
              ),
              Text(
                _clock(value.duration),
                style: AppTextStyles.mono(
                  fontSize: 10,
                  color: AppColors.shellstone.withValues(alpha: 0.66),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      iconSize: 22,
      color: AppColors.shellstone.withValues(alpha: 0.78),
      splashRadius: 20,
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SolenneGlass(padding: padding, borderRadius: 26, child: child);
  }
}

class _PreviewSkyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.sapphire.withValues(alpha: 0.24),
              AppColors.royalBlue.withValues(alpha: 0.12),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.52, size.height * 0.38),
              radius: size.shortestSide * 0.8,
            ),
          );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
