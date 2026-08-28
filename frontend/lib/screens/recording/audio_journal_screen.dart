import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/errors/user_error_message.dart';
import '../../core/widgets/solenne_audio_player.dart';
import '../../features/journals/journal_entry.dart';
import '../../features/journals/journal_repository.dart';
import '../../services/cloudinary/cloudinary_providers.dart';
import '../../services/cloudinary/cloudinary_upload_service.dart';
import '../../theme/app_theme.dart';
import 'entry_saved_screen.dart';

class AudioJournalScreen extends ConsumerStatefulWidget {
  const AudioJournalScreen({super.key});

  @override
  ConsumerState<AudioJournalScreen> createState() => _AudioJournalScreenState();
}

class _AudioJournalScreenState extends ConsumerState<AudioJournalScreen>
    with SingleTickerProviderStateMixin {
  static const _maxSeconds = 180;
  late final AudioRecorder _recorder;
  late final AnimationController _animation;
  Timer? _timer;
  int _seconds = 0;
  bool _recording = false;
  bool _paused = false;
  bool _saving = false;
  String? _recordedPath;
  String? _error;
  late final String _journalId;
  CloudinaryUploadResult? _uploadedAudio;
  final _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
    _journalId = DateTime.now().microsecondsSinceEpoch.toString();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _animation.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      if (!await _recorder.hasPermission()) {
        setState(() => _error = 'Microphone permission is required.');
        return;
      }
      final path = kIsWeb
          ? ''
          : '${(await getTemporaryDirectory()).path}/solenne-$_journalId.m4a';
      await _recorder.start(
        RecordConfig(
          encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          noiseSuppress: true,
          echoCancel: true,
        ),
        path: path,
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = userErrorMessage(
            error,
            fallback: 'The microphone could not be started.',
          ),
        );
      }
      return;
    }
    _animation.repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _paused) return;
      setState(() => _seconds++);
      if (_seconds >= _maxSeconds) _stop();
    });
    setState(() => _recording = true);
  }

  Future<void> _pauseResume() async {
    if (_paused) {
      await _recorder.resume();
    } else {
      await _recorder.pause();
    }
    setState(() => _paused = !_paused);
  }

  Future<void> _stop() async {
    final path = await _recorder.stop();
    _timer?.cancel();
    _animation.stop();
    setState(() {
      _recording = false;
      _paused = false;
      _recordedPath = path;
    });
  }

  Future<void> _discard() async {
    if (_recording) await _recorder.cancel();
    _timer?.cancel();
    setState(() {
      _recordedPath = null;
      _seconds = 0;
      _recording = false;
      _paused = false;
      _uploadedAudio = null;
    });
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    final path = _recordedPath;
    if (user == null || path == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final file = XFile(path, mimeType: kIsWeb ? 'audio/webm' : 'audio/mp4');
      final upload =
          _uploadedAudio ??
          await ref.read(cloudinaryUploadServiceProvider).uploadAudio(file);
      _uploadedAudio = upload;
      final entry = JournalEntry(
        id: _journalId,
        userId: user.uid,
        prompt: 'What has been on your mind today?',
        recordedAt: DateTime.now(),
        durationSeconds: _seconds,
        cloudinaryPublicId: upload.publicId,
        videoUrl: '',
        audioUrl: upload.secureUrl,
        thumbnailUrl: '',
        uploadStatus: 'saved',
        analysisStatus: 'queued',
        analysisStep: 'queued',
        analysisVersion: JournalRepository.analysisVersion,
        entryType: 'audio',
        mediaMimeType: kIsWeb ? 'audio/webm' : 'audio/mp4',
        analysisModalities: const ['transcript', 'voice', 'text'],
        title: _titleController.text.trim(),
      );
      await ref.read(journalRepositoryProvider).saveJournal(entry);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => EntrySavedScreen(entryId: _journalId),
        ),
        (_) => false,
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = userErrorMessage(
            error,
            fallback: 'This voice journal could not be saved.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _recordedPath;
    return Scaffold(
      body: SolenneBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Spacer(),
                    Text(
                      'VOICE JOURNAL',
                      style: AppTextStyles.mono(fontSize: 9),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  path != null
                      ? 'Listen back'
                      : _recording
                      ? 'I\'m listening'
                      : 'Speak freely',
                  style: AppTextStyles.display(fontSize: 36),
                ),
                const SizedBox(height: 8),
                Text(
                  _format(_seconds),
                  style: AppTextStyles.mono(
                    fontSize: 14,
                    color: AppColors.quicksand,
                  ),
                ),
                const SizedBox(height: 24),
                if (path != null) ...[
                  SolenneAudioPlayer(source: path, localFile: true),
                  const SizedBox(height: 14),
                  SolenneGlass(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 4,
                    ),
                    borderRadius: 18,
                    child: TextField(
                      controller: _titleController,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        hintText: 'Name this recording (optional)',
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                  ),
                ] else
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) => CustomPaint(
                      painter: _VoiceOrbPainter(
                        progress: _animation.value,
                        active: _recording && !_paused,
                      ),
                      child: const SizedBox(width: 220, height: 220),
                    ),
                  ),
                const Spacer(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                        fontSize: 11,
                        color: AppColors.quicksand,
                      ),
                    ),
                  ),
                if (path != null)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _discard,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Record again'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.cloud_upload_rounded),
                          label: Text(_saving ? 'Saving...' : 'Save entry'),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_recording) ...[
                        IconButton.filledTonal(
                          tooltip: _paused ? 'Resume' : 'Pause',
                          onPressed: _pauseResume,
                          icon: Icon(
                            _paused ? Icons.mic_rounded : Icons.pause_rounded,
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],
                      IconButton.filled(
                        tooltip: _recording ? 'Stop' : 'Start recording',
                        onPressed: _recording ? _stop : _start,
                        icon: Icon(
                          _recording ? Icons.stop_rounded : Icons.mic_rounded,
                        ),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(72, 72),
                          backgroundColor: AppColors.quicksand,
                          foregroundColor: AppColors.royalBlue,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _format(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class _VoiceOrbPainter extends CustomPainter {
  const _VoiceOrbPainter({required this.progress, required this.active});
  final double progress;
  final bool active;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.sapphire.withValues(alpha: active ? 0.68 : 0.4),
            AppColors.royalBlue.withValues(alpha: 0.24),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    for (var ring = 0; ring < 4; ring++) {
      final path = Path();
      for (var step = 0; step <= 72; step++) {
        final angle = step / 72 * math.pi * 2;
        final wave =
            math.sin(angle * (ring + 3) + progress * math.pi * 2) *
            (active ? 7 : 3);
        final ringRadius = radius * (0.3 + ring * 0.15) + wave;
        final point =
            center + Offset(math.cos(angle), math.sin(angle)) * ringRadius;
        step == 0
            ? path.moveTo(point.dx, point.dy)
            : path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.quicksand.withValues(alpha: active ? 0.28 : 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(_VoiceOrbPainter old) =>
      old.progress != progress || old.active != active;
}
