import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../features/journals/journal_entry.dart';
import '../../features/journals/journal_repository.dart';
import '../../routing/fade_through_route.dart';
import '../../theme/app_theme.dart';
import '../app_shell.dart';

class DailyInsightScreen extends ConsumerWidget {
  const DailyInsightScreen({super.key, required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryState = ref.watch(journalByIdStreamProvider(entryId));

    void close() {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
        return;
      }
      navigator.pushAndRemoveUntil(
        fadeThroughRoute(const AppShell()),
        (_) => false,
      );
    }

    return Scaffold(
      body: SolenneBackground(
        child: entryState.when(
          error: (_, _) => _EntryStateView(
            icon: Icons.cloud_off_outlined,
            title: 'This reflection could not be reached.',
            message: 'Check your connection and try opening it again.',
            onClose: close,
          ),
          loading: () => _LoadingEntryView(onClose: close),
          data: (entry) {
            if (entry == null) {
              return _EntryStateView(
                icon: Icons.hourglass_empty_rounded,
                title: 'This reflection is not here.',
                message: 'It may have been removed or is still being saved.',
                onClose: close,
              );
            }
            return _DailyEntryView(entry: entry, onClose: close);
          },
        ),
      ),
    );
  }
}

class _LoadingEntryView extends StatelessWidget {
  const _LoadingEntryView({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            left: 12,
            top: 10,
            child: IconButton(
              tooltip: 'Back',
              onPressed: onClose,
              icon: const Icon(Icons.arrow_back_rounded),
              color: AppColors.shellstone.withValues(alpha: 0.76),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 76,
                  height: 76,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.4,
                    color: AppColors.quicksand.withValues(alpha: 0.72),
                    backgroundColor: AppColors.sapphire.withValues(alpha: 0.2),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Opening your reflection…',
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.shellstone.withValues(alpha: 0.72),
                    fontStyle: FontStyle.italic,
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

class _EntryStateView extends StatelessWidget {
  const _EntryStateView({
    required this.icon,
    required this.title,
    required this.message,
    required this.onClose,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Back',
                onPressed: onClose,
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppColors.shellstone.withValues(alpha: 0.76),
              ),
            ),
            const Spacer(),
            Icon(
              icon,
              size: 38,
              color: AppColors.quicksand.withValues(alpha: 0.72),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.display(fontSize: 29),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 13,
                color: AppColors.shellstone.withValues(alpha: 0.68),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _DailyEntryView extends StatelessWidget {
  const _DailyEntryView({required this.entry, required this.onClose});

  final JournalEntry entry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat(
      'EEEE, d MMMM yyyy · h:mm a',
    ).format(entry.recordedAt);
    final showPrompt =
        entry.title.trim().isNotEmpty &&
        entry.prompt.trim().isNotEmpty &&
        entry.prompt.trim() != entry.displayTitle.trim();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 42),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: onClose,
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: AppColors.shellstone.withValues(alpha: 0.76),
                ),
                const Spacer(),
                _StatusPill(entry: entry),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'DAILY REFLECTION',
              style: AppTextStyles.mono(
                fontSize: 9,
                color: AppColors.quicksand.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              entry.displayTitle,
              style: AppTextStyles.display(fontSize: 38),
            ),
            const SizedBox(height: 5),
            Text(
              dateLabel,
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.shellstone.withValues(alpha: 0.62),
              ),
            ),
            if (showPrompt) ...[
              const SizedBox(height: 12),
              Text(
                entry.prompt,
                style: AppTextStyles.body(
                  fontSize: 14,
                  color: AppColors.shellstone.withValues(alpha: 0.8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 20),
            JournalVideoPlayer(entry: entry),
            const SizedBox(height: 12),
            _EntryMetadata(entry: entry),
            const SizedBox(height: 12),
            _TranscriptAction(entry: entry),
            const SizedBox(height: 26),
            _AnalysisBody(entry: entry),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final normalized = entry.analysisStatus.toLowerCase();
    final complete = normalized == 'complete';
    final failed = normalized == 'failed';
    final label = complete
        ? 'INSIGHTS READY'
        : failed
        ? 'ANALYSIS PAUSED'
        : normalized == 'processing'
        ? 'ANALYZING · ${_analysisStepLabel(entry.analysisStep)}'
        : 'QUEUED FOR ANALYSIS';
    final color = failed ? AppColors.shellstone : AppColors.quicksand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.09),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: AppTextStyles.mono(
          fontSize: 7,
          color: color.withValues(alpha: 0.78),
        ),
      ),
    );
  }
}

class _EntryMetadata extends StatelessWidget {
  const _EntryMetadata({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MetadataItem(
          icon: Icons.schedule_rounded,
          label: _formatClock(Duration(seconds: entry.durationSeconds)),
        ),
        const SizedBox(width: 16),
        _MetadataItem(
          icon: Icons.cloud_done_outlined,
          label: entry.uploadStatus.toUpperCase(),
        ),
        if (entry.moodLabel?.trim().isNotEmpty == true) ...[
          const SizedBox(width: 16),
          Expanded(
            child: _MetadataItem(
              icon: Icons.blur_on_rounded,
              label: entry.moodLabel!.trim().toUpperCase(),
            ),
          ),
        ],
      ],
    );
  }
}

class _MetadataItem extends StatelessWidget {
  const _MetadataItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: AppColors.quicksand.withValues(alpha: 0.62),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.mono(
              fontSize: 8,
              color: AppColors.shellstone.withValues(alpha: 0.56),
            ),
          ),
        ),
      ],
    );
  }
}

class _TranscriptAction extends StatelessWidget {
  const _TranscriptAction({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final available = entry.transcript.isAvailable;
    final failed = entry.analysisStatus.toLowerCase() == 'failed';
    final label = available
        ? 'Show transcript'
        : failed
        ? 'Transcript unavailable'
        : 'Transcript is being prepared';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: available ? () => _showTranscript(context, entry) : null,
      child: SolenneGlass(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        borderRadius: 18,
        tint: AppColors.sapphire,
        child: Row(
          children: [
            Icon(
              available ? Icons.subject_rounded : Icons.graphic_eq_rounded,
              size: 17,
              color: AppColors.quicksand.withValues(
                alpha: available ? 0.82 : 0.48,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.mono(
                  fontSize: 9,
                  color: AppColors.shellstone.withValues(
                    alpha: available ? 0.78 : 0.5,
                  ),
                ),
              ),
            ),
            if (available)
              Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: AppColors.shellstone.withValues(alpha: 0.55),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTranscript(BuildContext context, JournalEntry entry) async {
    final transcript = entry.transcript;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.48,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SolenneGlass(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            borderRadius: 28,
            tint: AppColors.sapphire,
            child: ListView(
              controller: controller,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: AppColors.shellstone.withValues(alpha: 0.28),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Your words', style: AppTextStyles.display(fontSize: 31)),
                const SizedBox(height: 5),
                Text(
                  [
                    if (transcript.language?.trim().isNotEmpty == true)
                      transcript.language!.toUpperCase(),
                    '${transcript.wordCount} WORDS',
                  ].join(' · '),
                  style: AppTextStyles.mono(
                    fontSize: 8,
                    color: AppColors.quicksand.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: 18),
                SelectableText(
                  transcript.text,
                  style: AppTextStyles.body(
                    fontSize: 15,
                    color: AppColors.shellstone.withValues(alpha: 0.86),
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

class JournalVideoPlayer extends StatefulWidget {
  const JournalVideoPlayer({super.key, required this.entry});

  final JournalEntry entry;

  @override
  State<JournalVideoPlayer> createState() => _JournalVideoPlayerState();
}

class _JournalVideoPlayerState extends State<JournalVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initializing = false;
  bool _muted = false;
  bool _hasStarted = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant JournalVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.videoUrl != widget.entry.videoUrl) _initialize();
  }

  @override
  void dispose() {
    _generation++;
    _controller?.removeListener(_refresh);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final generation = ++_generation;
    final oldController = _controller;
    oldController?.removeListener(_refresh);
    _controller = null;
    await oldController?.dispose();

    final source = widget.entry.videoUrl.trim();
    final uri = Uri.tryParse(source);
    if (source.isEmpty || uri == null || !uri.hasScheme) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _initializing = false;
        _error = 'No playable video URL was saved for this reflection.';
      });
      return;
    }

    setState(() {
      _initializing = true;
      _error = null;
      _hasStarted = false;
    });
    final controller = VideoPlayerController.networkUrl(uri);
    try {
      await controller.initialize();
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      controller.addListener(_refresh);
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (_) {
      await controller.dispose();
      if (!mounted || generation != _generation) return;
      setState(() {
        _initializing = false;
        _error = 'The saved video could not be loaded from Cloudinary.';
      });
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      setState(() => _hasStarted = true);
      await controller.play();
    }
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;
    final muted = !_muted;
    await controller.setVolume(muted ? 0 : 1);
    if (mounted) setState(() => _muted = muted);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initialized = controller?.value.isInitialized == true;
    final aspectRatio = initialized && controller!.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : 16 / 10;

    return SolenneGlass(
      padding: const EdgeInsets.all(8),
      borderRadius: 24,
      tint: AppColors.sapphire,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ColoredBox(
            color: const Color(0xFF07102A),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (initialized)
                  Positioned.fill(child: VideoPlayer(controller!)),
                if (!initialized || !_hasStarted)
                  Positioned.fill(child: _VideoPoster(entry: widget.entry)),
                if (_initializing)
                  CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.quicksand.withValues(alpha: 0.8),
                  ),
                if (_error != null)
                  _VideoError(message: _error!, onRetry: _initialize),
                if (initialized && _error == null) ...[
                  if (!_hasStarted)
                    _PlayButton(onPressed: _togglePlayback)
                  else
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _togglePlayback,
                      ),
                    ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 9,
                    child: _VideoControls(
                      controller: controller!,
                      muted: _muted,
                      onPlayPause: _togglePlayback,
                      onMute: _toggleMute,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoPoster extends StatelessWidget {
  const _VideoPoster({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final thumbnail = entry.effectiveThumbnailUrl;
    if (thumbnail.isEmpty) return const _PosterFallback();
    return Image.network(
      thumbnail,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const _PosterFallback(),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _VideoAtmospherePainter());
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.quicksand.withValues(alpha: 0.9),
          boxShadow: [
            BoxShadow(
              color: AppColors.quicksand.withValues(alpha: 0.22),
              blurRadius: 28,
            ),
          ],
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          size: 35,
          color: AppColors.royalBlue,
        ),
      ),
    );
  }
}

class _VideoError extends StatelessWidget {
  const _VideoError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: AppColors.shellstone.withValues(alpha: 0.72),
          ),
          const SizedBox(height: 9),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              fontSize: 11,
              color: AppColors.shellstone.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 9),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Try again'),
            style: TextButton.styleFrom(foregroundColor: AppColors.quicksand),
          ),
        ],
      ),
    );
  }
}

class _VideoControls extends StatelessWidget {
  const _VideoControls({
    required this.controller,
    required this.muted,
    required this.onPlayPause,
    required this.onMute,
  });

  final VideoPlayerController controller;
  final bool muted;
  final VoidCallback onPlayPause;
  final VoidCallback onMute;

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    final durationMs = math.max(1, value.duration.inMilliseconds);
    final positionMs = value.position.inMilliseconds.clamp(0, durationMs);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 7, 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withValues(alpha: 0.58),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onPlayPause,
            child: Icon(
              value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 20,
              color: AppColors.swanWing,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            _formatClock(value.position),
            style: AppTextStyles.mono(
              fontSize: 7,
              color: AppColors.shellstone.withValues(alpha: 0.8),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 1.5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 9),
                activeTrackColor: AppColors.quicksand,
                inactiveTrackColor: AppColors.shellstone.withValues(
                  alpha: 0.25,
                ),
                thumbColor: AppColors.quicksand,
                overlayColor: AppColors.quicksand.withValues(alpha: 0.12),
              ),
              child: Slider(
                min: 0,
                max: durationMs.toDouble(),
                value: positionMs.toDouble(),
                onChanged: (next) =>
                    controller.seekTo(Duration(milliseconds: next.round())),
              ),
            ),
          ),
          Text(
            _formatClock(value.duration),
            style: AppTextStyles.mono(
              fontSize: 7,
              color: AppColors.shellstone.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onMute,
            child: Icon(
              muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              size: 18,
              color: AppColors.shellstone.withValues(alpha: 0.84),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisBody extends StatelessWidget {
  const _AnalysisBody({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    if (entry.aiInsights.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What surfaced', style: AppTextStyles.display(fontSize: 31)),
          const SizedBox(height: 4),
          Text(
            'Gentle observations from this reflection—not a diagnosis.',
            style: AppTextStyles.body(
              fontSize: 12,
              color: AppColors.shellstone.withValues(alpha: 0.66),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          for (int index = 0; index < entry.aiInsights.length; index++) ...[
            _InsightCard(insight: entry.aiInsights[index], index: index),
            if (index != entry.aiInsights.length - 1)
              const SizedBox(height: 14),
          ],
        ],
      );
    }

    final status = entry.analysisStatus.toLowerCase();
    if (status == 'failed') {
      return const _AnalysisStateCard(
        icon: Icons.waves_outlined,
        eyebrow: 'ANALYSIS PAUSED',
        title: 'Your video is safe.',
        message:
            'Insights could not be prepared this time. You can still revisit the reflection whenever you want.',
      );
    }
    if (status == 'complete') {
      return const _AnalysisStateCard(
        icon: Icons.nights_stay_outlined,
        eyebrow: 'NO INSIGHTS RETURNED',
        title: 'Nothing needs to be forced.',
        message:
            'The analysis finished without a reliable reflection to show. Your journal remains here, exactly as you recorded it.',
      );
    }
    if (status == 'processing') {
      return _AnalysisStateCard(
        icon: Icons.auto_awesome_rounded,
        eyebrow: 'ANALYSIS IN PROGRESS',
        title: _analysisStepTitle(entry.analysisStep),
        message:
            'Solenne will update this page automatically when the next stage is ready.',
      );
    }
    return const _AnalysisStateCard(
      icon: Icons.auto_awesome_rounded,
      eyebrow: 'INSIGHTS ARE STILL SETTLING',
      title: 'Your reflection is saved.',
      message:
          'Your reflection is waiting for the private analysis worker. This page will update automatically.',
    );
  }
}

String _analysisStepLabel(String step) {
  final normalized = step.trim().toLowerCase();
  return switch (normalized) {
    'downloading' => 'DOWNLOADING',
    'validate' => 'CHECKING VIDEO',
    'media' => 'PREPARING AUDIO',
    'transcribe' || 'transcribing' => 'TRANSCRIBING',
    'face' => 'READING EXPRESSION',
    'voice' => 'LISTENING TO RHYTHM',
    'nlp' => 'UNDERSTANDING WORDS',
    'fusion' => 'CONNECTING SIGNALS',
    'insights' || 'ai_insights' => 'FORMING INSIGHTS',
    _ => 'PREPARING',
  };
}

String _analysisStepTitle(String step) {
  return switch (_analysisStepLabel(step)) {
    'DOWNLOADING' => 'Bringing your reflection into the room.',
    'CHECKING VIDEO' => 'Making sure the recording arrived clearly.',
    'PREPARING AUDIO' => 'Preparing the sound of your reflection.',
    'TRANSCRIBING' => 'Turning your voice into words.',
    'READING EXPRESSION' => 'Noticing expression with care.',
    'LISTENING TO RHYTHM' => 'Listening for pace and energy.',
    'UNDERSTANDING WORDS' => 'Finding the themes in what you shared.',
    'CONNECTING SIGNALS' => 'Bringing the different signals together.',
    'FORMING INSIGHTS' => 'Shaping a few gentle observations.',
    _ => 'Your reflection is beginning to settle.',
  };
}

class _AnalysisStateCard extends StatelessWidget {
  const _AnalysisStateCard({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SolenneGlass(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      borderRadius: 22,
      tint: AppColors.sapphire,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.quicksand.withValues(alpha: 0.1),
              border: Border.all(
                color: AppColors.quicksand.withValues(alpha: 0.18),
              ),
            ),
            child: Icon(
              icon,
              size: 21,
              color: AppColors.quicksand.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: AppTextStyles.mono(
                    fontSize: 8,
                    color: AppColors.quicksand.withValues(alpha: 0.66),
                  ),
                ),
                const SizedBox(height: 6),
                Text(title, style: AppTextStyles.display(fontSize: 25)),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.shellstone.withValues(alpha: 0.7),
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

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight, required this.index});

  final AiInsight insight;
  final int index;

  @override
  Widget build(BuildContext context) {
    final evidenceRows = _flattenEvidence(insight.evidence);
    return SolenneGlass(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      borderRadius: 23,
      tint: index.isEven ? AppColors.sapphire : AppColors.quicksand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'INSIGHT ${(index + 1).toString().padLeft(2, '0')}',
                style: AppTextStyles.mono(
                  fontSize: 8,
                  color: AppColors.quicksand.withValues(alpha: 0.72),
                ),
              ),
              const Spacer(),
              if (insight.moodLabel.trim().isNotEmpty)
                _MoodChip(label: insight.moodLabel),
            ],
          ),
          const SizedBox(height: 13),
          if (insight.title.trim().isNotEmpty)
            Text(insight.title, style: AppTextStyles.display(fontSize: 28)),
          if (insight.summary.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              insight.summary,
              style: AppTextStyles.body(
                fontSize: 14,
                color: AppColors.shellstone.withValues(alpha: 0.84),
              ),
            ),
          ],
          if (insight.dayThemes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final theme in insight.dayThemes) _ThemeChip(label: theme),
              ],
            ),
          ],
          if (insight.suggestions.isNotEmpty) ...[
            const SizedBox(height: 19),
            const _InsightSectionLabel(
              icon: Icons.spa_outlined,
              label: 'A GENTLE NEXT STEP',
            ),
            const SizedBox(height: 9),
            for (final suggestion in insight.suggestions)
              _InsightLine(icon: Icons.arrow_outward_rounded, text: suggestion),
          ],
          if (insight.reflectionQuestions.isNotEmpty) ...[
            const SizedBox(height: 17),
            const _InsightSectionLabel(
              icon: Icons.blur_on_rounded,
              label: 'QUESTIONS TO CARRY',
            ),
            const SizedBox(height: 9),
            for (final question in insight.reflectionQuestions)
              _InsightLine(icon: Icons.circle_outlined, text: question),
          ],
          if (insight.safetyNote.trim().isNotEmpty) ...[
            const SizedBox(height: 17),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: AppColors.quicksand.withValues(alpha: 0.08),
                border: Border.all(
                  color: AppColors.quicksand.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 17,
                    color: AppColors.quicksand.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      insight.safetyNote,
                      style: AppTextStyles.body(
                        fontSize: 11,
                        color: AppColors.shellstone.withValues(alpha: 0.78),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 17),
          _ConfidenceBar(confidence: insight.confidence),
          if (evidenceRows.isNotEmpty) ...[
            const SizedBox(height: 6),
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 4),
                iconColor: AppColors.quicksand,
                collapsedIconColor: AppColors.shellstone.withValues(
                  alpha: 0.56,
                ),
                title: Text(
                  'WHY THIS APPEARED',
                  style: AppTextStyles.mono(
                    fontSize: 8,
                    color: AppColors.shellstone.withValues(alpha: 0.62),
                  ),
                ),
                children: [
                  for (final row in evidenceRows) _EvidenceRow(row: row),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppColors.sapphire.withValues(alpha: 0.24),
        border: Border.all(color: AppColors.shellstone.withValues(alpha: 0.14)),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.mono(
          fontSize: 7,
          color: AppColors.shellstone.withValues(alpha: 0.74),
        ),
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: AppColors.sapphire.withValues(alpha: 0.19),
        border: Border.all(color: AppColors.shellstone.withValues(alpha: 0.13)),
      ),
      child: Text(
        label,
        style: AppTextStyles.mono(
          fontSize: 8,
          color: AppColors.shellstone.withValues(alpha: 0.78),
        ),
      ),
    );
  }
}

class _InsightSectionLabel extends StatelessWidget {
  const _InsightSectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: AppColors.quicksand.withValues(alpha: 0.72),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: AppTextStyles.mono(
            fontSize: 8,
            color: AppColors.quicksand.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _InsightLine extends StatelessWidget {
  const _InsightLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(
              icon,
              size: 12,
              color: AppColors.quicksand.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.shellstone.withValues(alpha: 0.78),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  const _ConfidenceBar({required this.confidence});

  final double confidence;

  @override
  Widget build(BuildContext context) {
    final safe = confidence.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'SIGNAL CONFIDENCE',
              style: AppTextStyles.mono(
                fontSize: 7,
                color: AppColors.shellstone.withValues(alpha: 0.48),
              ),
            ),
            const Spacer(),
            Text(
              '${(safe * 100).round()}%',
              style: AppTextStyles.mono(
                fontSize: 7,
                color: AppColors.shellstone.withValues(alpha: 0.58),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 2,
            value: safe,
            backgroundColor: AppColors.shellstone.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(
              AppColors.quicksand.withValues(alpha: 0.72),
            ),
          ),
        ),
      ],
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.row});

  final _EvidenceValue row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              row.label.toUpperCase(),
              style: AppTextStyles.mono(
                fontSize: 7,
                color: AppColors.shellstone.withValues(alpha: 0.46),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              row.value,
              textAlign: TextAlign.right,
              style: AppTextStyles.body(
                fontSize: 10,
                color: AppColors.shellstone.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceValue {
  const _EvidenceValue(this.label, this.value);

  final String label;
  final String value;
}

List<_EvidenceValue> _flattenEvidence(Map<String, dynamic> evidence) {
  final rows = <_EvidenceValue>[];

  void visit(String prefix, Object? value) {
    if (value == null) return;
    if (value is Map) {
      for (final item in value.entries) {
        final label = prefix.isEmpty
            ? item.key.toString()
            : '$prefix · ${item.key}';
        visit(label, item.value);
      }
      return;
    }
    if (value is Iterable) {
      final text = value.map((item) => item.toString()).join(', ').trim();
      if (text.isNotEmpty) rows.add(_EvidenceValue(_humanize(prefix), text));
      return;
    }
    final text = value.toString().trim();
    if (text.isNotEmpty) rows.add(_EvidenceValue(_humanize(prefix), text));
  }

  visit('', evidence);
  return rows;
}

String _humanize(String value) {
  return value
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      )
      .replaceAll('_', ' ')
      .replaceAll(' · ', ' / ')
      .trim();
}

String _formatClock(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class _VideoAtmospherePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C315F), Color(0xFF0B1737), Color(0xFF050A1D)],
        ).createShader(rect),
    );
    final center = Offset(size.width * 0.54, size.height * 0.44);
    for (int ring = 0; ring < 4; ring++) {
      canvas.drawCircle(
        center,
        size.shortestSide * (0.12 + ring * 0.1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = (ring.isEven ? AppColors.quicksand : AppColors.shellstone)
              .withValues(alpha: 0.09 + ring * 0.035),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
