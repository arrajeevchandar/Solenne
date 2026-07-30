import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_theme.dart';
import '../../features/recording/recording_draft.dart';
import 'recording_preview_screen.dart';

enum _RecordingState { idle, recording, paused, stopped, received }

@visibleForTesting
bool recordingCompletionActionsVisible({
  required bool isPaused,
  required bool isReceived,
}) =>
    isPaused || isReceived;

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _roomController;
  late final AnimationController _listenController;
  CameraController? _cameraController;
  Future<void>? _cameraInit;
  XFile? _recordedVideo;
  String? _cameraError;
  Timer? _recordingTimer;
  int _elapsedSeconds = 0;
  _RecordingState _state = _RecordingState.idle;
  bool _showPrompt = true;
  Timer? _receivedTimer;
  static const _maxSeconds = 180;
  static const _prompt = "What's been on your mind today?";

  @override
  void initState() {
    super.initState();
    _roomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 14000),
    )..repeat();
    _listenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _cameraInit = _initializeCamera();
  }

  @override
  void dispose() {
    _receivedTimer?.cancel();
    _recordingTimer?.cancel();
    _roomController.dispose();
    _listenController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final camera = await Permission.camera.request();
      final microphone = await Permission.microphone.request();
      if (!camera.isGranted || !microphone.isGranted) {
        setState(() {
          _cameraError =
              'Camera and microphone permissions are needed to record.';
        });
        return;
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'No camera available.');
        return;
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      _cameraController = controller;
      await controller.initialize();
      if (mounted) setState(() {});
    } on CameraException catch (error) {
      if (mounted) setState(() => _cameraError = error.description);
    } catch (_) {
      if (mounted) {
        setState(() => _cameraError = 'Camera could not be opened.');
      }
    }
  }

  Future<void> _begin() async {
    final controller = _cameraController;
    if (controller == null || _cameraError != null) return;
    try {
      await _cameraInit;
      if (!controller.value.isInitialized ||
          controller.value.isRecordingVideo) {
        return;
      }
      await controller.startVideoRecording();
      if (!mounted) return;
      setState(() {
        _recordedVideo = null;
        _elapsedSeconds = 0;
        _state = _RecordingState.recording;
      });
      _listenController.repeat(reverse: true);
      _startElapsedTimer();
    } on CameraException catch (error) {
      if (mounted) setState(() => _cameraError = error.description);
    }
  }

  void _startElapsedTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      if (_elapsedSeconds + 1 >= _maxSeconds) {
        await _finalize();
      } else {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  /// Pauses the in-progress recording without discarding it. Tapping "keep
  /// going" later resumes the same file from this exact point.
  Future<void> _pause() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isRecordingVideo) return;
    try {
      await controller.pauseVideoRecording();
    } on CameraException catch (error) {
      if (mounted) setState(() => _cameraError = error.description);
      return;
    }
    _listenController.stop();
    _recordingTimer?.cancel();
    _receivedTimer?.cancel();
    setState(() => _state = _RecordingState.paused);
  }

  /// Resumes a paused recording, continuing the same file and elapsed time.
  Future<void> _keepGoing() async {
    final controller = _cameraController;
    if (controller == null) return;
    _receivedTimer?.cancel();
    if (!controller.value.isRecordingVideo) {
      // Nothing is paused to resume (e.g. camera was reset) — start fresh.
      await _begin();
      return;
    }
    try {
      await controller.resumeVideoRecording();
    } on CameraException catch (error) {
      if (mounted) setState(() => _cameraError = error.description);
      return;
    }
    if (!mounted) return;
    setState(() => _state = _RecordingState.recording);
    _listenController.repeat(reverse: true);
    _startElapsedTimer();
  }

  /// Discards any in-progress or paused recording and returns to the start so
  /// the whole video can be recorded again.
  Future<void> _retake() async {
    final controller = _cameraController;
    _receivedTimer?.cancel();
    _recordingTimer?.cancel();
    _listenController.stop();
    _listenController.reset();
    if (controller != null && controller.value.isRecordingVideo) {
      try {
        // Stop and drop the partial file; we do not keep the result.
        await controller.stopVideoRecording();
      } on CameraException catch (_) {
        // Ignore — we are discarding this recording regardless.
      }
    }
    if (!mounted) return;
    setState(() {
      _recordedVideo = null;
      _elapsedSeconds = 0;
      _state = _RecordingState.idle;
    });
  }

  /// Finalizes the recording into a single file ready for review/upload.
  Future<void> _finalize() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isRecordingVideo) return;

    XFile video;
    try {
      video = await controller.stopVideoRecording();
    } on CameraException catch (error) {
      if (mounted) setState(() => _cameraError = error.description);
      return;
    }

    _listenController.stop();
    _listenController.reset();
    _recordingTimer?.cancel();
    setState(() {
      _recordedVideo = video;
      _state = _RecordingState.stopped;
    });
    _reviewRecording();
  }

  void _reviewRecording() {
    final video = _recordedVideo;
    if (video == null) return;
    _receivedTimer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => RecordingPreviewScreen(
          draft: RecordingDraft(
            file: video,
            durationSeconds: _elapsedSeconds.clamp(1, _maxSeconds),
            prompt: _prompt,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = _state == _RecordingState.recording;
    final isPaused = _state == _RecordingState.paused;
    final isReceived = _state == _RecordingState.received;
    final showCompletionActions = recordingCompletionActionsVisible(
      isPaused: isPaused,
      isReceived: isReceived,
    );
    final screenSize = MediaQuery.of(context).size;
    final compact = screenSize.height < 740;
    final previewHeight = math.min(
      screenSize.height * (compact ? 0.54 : 0.62),
      screenSize.width * (compact ? 1.1 : 1.42),
    );

    return Scaffold(
      body: SizedBox.expand(
        child: SolenneBackground(
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _roomController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _PrivateRoomPainter(
                        progress: _roomController.value,
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 34),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 16,
                              color: AppColors.shellstone.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'private room',
                            style: AppTextStyles.mono(
                              fontSize: 10,
                              color: AppColors.shellstone.withValues(
                                alpha: 0.54,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      AnimatedSwitcher(
                        duration: AppDurations.transition,
                        child: _showPrompt
                            ? Dismissible(
                                key: const ValueKey('prompt'),
                                direction: DismissDirection.horizontal,
                                onDismissed: (_) {
                                  setState(() => _showPrompt = false);
                                },
                                child: const _SoftPrompt(),
                              )
                            : const SizedBox(key: ValueKey('no-prompt')),
                      ),
                      const SizedBox(height: 18),
                      AnimatedBuilder(
                        animation: _listenController,
                        builder: (context, _) {
                          return GestureDetector(
                            onTap: isRecording
                                ? _pause
                                : isPaused
                                ? _keepGoing
                                : _begin,
                            child: _CameraPresence(
                              controller: _cameraController,
                              cameraInit: _cameraInit,
                              cameraError: _cameraError,
                              progress: _listenController.value,
                              isRecording: isRecording,
                              isPaused: isPaused,
                              isReceived: isReceived,
                              height: previewHeight,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: AppDurations.transition,
                        child: isReceived
                            ? Text(
                                'Entry received.',
                                key: const ValueKey('received'),
                                style: AppTextStyles.display(fontSize: 30),
                                textAlign: TextAlign.center,
                              )
                            : Text(
                                isRecording
                                    ? 'Solenne is listening.'
                                    : isPaused
                                    ? 'Paused.'
                                    : 'Tap to begin.',
                                key: ValueKey(_state),
                                style: AppTextStyles.body(
                                  fontSize: 15,
                                  color: AppColors.shellstone.withValues(
                                    alpha: 0.72,
                                  ),
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 58,
                        child: AnimatedSwitcher(
                          duration: AppDurations.transition,
                          child: isRecording
                              ? _Waveform(
                                  key: const ValueKey('waveform'),
                                  progress: _roomController.value,
                                )
                              : showCompletionActions
                              ? _DoneChoices(
                                  key: const ValueKey('choices'),
                                  onDone: _finalize,
                                  onKeepGoing: _keepGoing,
                                  onRetake: _retake,
                                )
                              : const SizedBox(key: ValueKey('empty')),
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
    );
  }
}

class _SoftPrompt extends StatelessWidget {
  const _SoftPrompt();

  @override
  Widget build(BuildContext context) {
    return SolenneGlass(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      borderRadius: 20,
      child: Text(
        "What's been on your mind today?",
        style: AppTextStyles.body(
          fontSize: 15,
          color: AppColors.shellstone.withValues(alpha: 0.82),
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _CameraPresence extends StatelessWidget {
  final CameraController? controller;
  final Future<void>? cameraInit;
  final String? cameraError;
  final double progress;
  final bool isRecording;
  final bool isPaused;
  final bool isReceived;
  final double height;

  const _CameraPresence({
    required this.controller,
    required this.cameraInit,
    required this.cameraError,
    required this.progress,
    required this.isRecording,
    required this.isPaused,
    required this.isReceived,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final pulse = isRecording ? 1 + progress * 0.035 : 1.0;
    return Transform.scale(
      scale: pulse,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _CameraPreviewLayer(
                  controller: controller,
                  cameraInit: cameraInit,
                  cameraError: cameraError,
                ),
                CustomPaint(
                  painter: _CameraPresencePainter(
                    progress: progress,
                    isRecording: isRecording,
                    isReceived: isReceived,
                  ),
                ),
                Center(
                  child: Icon(
                    isReceived
                        ? Icons.check_rounded
                        : isRecording
                        ? Icons.pause_rounded
                        : isPaused
                        ? Icons.play_arrow_rounded
                        : Icons.videocam_outlined,
                    size: 38,
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

class _CameraPreviewLayer extends StatelessWidget {
  final CameraController? controller;
  final Future<void>? cameraInit;
  final String? cameraError;

  const _CameraPreviewLayer({
    required this.controller,
    required this.cameraInit,
    required this.cameraError,
  });

  @override
  Widget build(BuildContext context) {
    if (cameraError != null) {
      return Container(
        color: AppColors.royalBlue.withValues(alpha: 0.35),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Text(
          cameraError!,
          style: AppTextStyles.body(
            fontSize: 13,
            color: AppColors.shellstone.withValues(alpha: 0.7),
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final controller = this.controller;
    final init = cameraInit;
    if (controller == null || init == null) {
      return ColoredBox(color: AppColors.royalBlue.withValues(alpha: 0.32));
    }

    return FutureBuilder<void>(
      future: init,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            !controller.value.isInitialized) {
          return ColoredBox(color: AppColors.royalBlue.withValues(alpha: 0.32));
        }

        return Opacity(
          opacity: 0.58,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.previewSize?.height ?? 1,
              height: controller.value.previewSize?.width ?? 1,
              child: CameraPreview(controller),
            ),
          ),
        );
      },
    );
  }
}

class _CameraPresencePainter extends CustomPainter {
  final double progress;
  final bool isRecording;
  final bool isReceived;

  const _CameraPresencePainter({
    required this.progress,
    required this.isRecording,
    required this.isReceived,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.shortestSide * 0.09);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.sapphire.withValues(alpha: 0.22),
            AppColors.royalBlue.withValues(alpha: 0.32),
            Colors.black.withValues(alpha: 0.3),
          ],
        ).createShader(rect),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(1.5),
        Radius.circular(size.shortestSide * 0.085),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.quicksand.withValues(
          alpha: isRecording ? 0.36 + progress * 0.18 : 0.18,
        ),
    );

    final random = math.Random(54);
    for (int i = 0; i < 26; i++) {
      final point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      canvas.drawCircle(
        point,
        10 + random.nextDouble() * 30,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.sapphire.withValues(alpha: 0.025),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: point, radius: 36)),
      );
    }
  }

  @override
  bool shouldRepaint(_CameraPresencePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isRecording != isRecording ||
      oldDelegate.isReceived != isReceived;
}

class _Waveform extends StatelessWidget {
  final double progress;

  const _Waveform({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WaveformPainter(progress: progress),
      child: const SizedBox(width: 240, height: 52),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;

  const _WaveformPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..color = AppColors.quicksand.withValues(alpha: 0.48);
    final centerY = size.height / 2;
    for (int i = 0; i < 34; i++) {
      final x = (i / 33) * size.width;
      final wave =
          math.sin(progress * math.pi * 2 + i * 0.72) * 0.5 +
          math.sin(progress * math.pi * 4 + i * 0.3) * 0.5;
      final height = 5 + wave.abs() * 18;
      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _DoneChoices extends StatelessWidget {
  final VoidCallback onDone;
  final VoidCallback onKeepGoing;
  final VoidCallback onRetake;

  const _DoneChoices({
    super.key,
    required this.onDone,
    required this.onKeepGoing,
    required this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onDone,
          child: Text(
            'Done',
            style: AppTextStyles.mono(
              fontSize: 13,
              color: AppColors.quicksand.withValues(alpha: 0.88),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: onKeepGoing,
              child: Text(
                'keep going',
                style: AppTextStyles.body(
                  fontSize: 13,
                  color: AppColors.shellstone.withValues(alpha: 0.62),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            Text(
              '  ·  ',
              style: AppTextStyles.body(
                fontSize: 13,
                color: AppColors.shellstone.withValues(alpha: 0.4),
              ),
            ),
            GestureDetector(
              onTap: onRetake,
              child: Text(
                'retake',
                style: AppTextStyles.body(
                  fontSize: 13,
                  color: AppColors.shellstone.withValues(alpha: 0.62),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PrivateRoomPainter extends CustomPainter {
  final double progress;

  const _PrivateRoomPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    for (int i = 0; i < 110; i++) {
      final twinkle = 0.45 + 0.25 * math.sin(progress * math.pi * 2 + i);
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        0.2 + random.nextDouble() * 0.66,
        Paint()
          ..color = AppColors.shellstone.withValues(
            alpha: 0.08 + twinkle * 0.18,
          ),
      );
    }

    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.sapphire.withValues(alpha: 0.22),
              AppColors.quicksand.withValues(alpha: 0.05),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.52, size.height * 0.55),
              radius: size.shortestSide * 0.82,
            ),
          );
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(_PrivateRoomPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
