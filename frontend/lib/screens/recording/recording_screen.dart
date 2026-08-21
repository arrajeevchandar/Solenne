import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../features/recording/camera_operation_queue.dart';
import '../../features/recording/camera_visibility_observer.dart';
import '../../theme/app_theme.dart';
import '../../features/recording/recording_draft.dart';
import 'recording_preview_screen.dart';

enum _RecordingState { idle, recording, paused, stopped, received }

@visibleForTesting
bool recordingCompletionActionsVisible({
  required bool isPaused,
  required bool isReceived,
}) => isPaused || isReceived;

@visibleForTesting
bool recordingUsesFlutterLifecycle({required bool isWeb}) => !isWeb;

@visibleForTesting
String recordingCameraErrorMessage(String code, String? description) {
  return switch (code) {
    'CameraAccessDenied' || 'AudioAccessDenied' =>
      'Camera and microphone access is needed to record. Allow access in your browser or device settings, then retry.',
    'cameraNotReadable' =>
      'The camera or microphone stream could not start. Close other apps or tabs using either device, then retry.',
    'cameraNotFound' => 'No camera was found on this device.',
    'cameraOverconstrained' =>
      'This camera could not use the requested recording settings. Try another camera.',
    'cameraSecurity' || 'cameraType' =>
      'Camera recording is unavailable in this browser or connection.',
    _ =>
      description?.trim().isNotEmpty == true
          ? description!.trim()
          : 'Camera could not be opened. Check the device and retry.',
  };
}

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _roomController;
  late final AnimationController _listenController;
  CameraController? _cameraController;
  Future<void>? _cameraInit;
  final CameraOperationQueue _cameraOperations = CameraOperationQueue();
  late final CameraVisibilityObserver _cameraVisibilityObserver;
  XFile? _recordedVideo;
  String? _cameraError;
  List<CameraDescription> _cameras = const [];
  int _selectedCameraIndex = 0;
  int _cameraGeneration = 0;
  bool _cameraSuspended = false;
  bool _hasSelectedPreferredCamera = false;
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
    WidgetsBinding.instance.addObserver(this);
    _roomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 14000),
    )..repeat();
    _listenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _cameraVisibilityObserver = CameraVisibilityObserver(
      onVisibilityChanged: _onWebVisibilityChanged,
    )..start();
    _scheduleCameraInitialization();
  }

  @override
  void dispose() {
    _receivedTimer?.cancel();
    _recordingTimer?.cancel();
    _roomController.dispose();
    _listenController.dispose();
    _cameraVisibilityObserver.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _cameraGeneration++;
    _cameraOperations.cancelInitialization();
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!recordingUsesFlutterLifecycle(isWeb: kIsWeb)) return;
    if (_state == _RecordingState.recording ||
        _state == _RecordingState.paused) {
      return;
    }
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _suspendIdleCamera();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _resumeIdleCamera();
    }
  }

  void _onWebVisibilityChanged(bool isVisible) {
    if (!kIsWeb || !mounted) return;
    if (_state == _RecordingState.recording ||
        _state == _RecordingState.paused) {
      return;
    }
    if (isVisible) {
      _resumeIdleCamera();
    } else {
      _suspendIdleCamera();
    }
  }

  void _suspendIdleCamera() {
    if (_cameraSuspended) return;
    _cameraSuspended = true;
    _cameraGeneration++;
    _cameraOperations.cancelInitialization();
    final release = _cameraOperations.enqueue(_disposeCurrentCamera);
    if (mounted) {
      setState(() {
        _cameraInit = release;
      });
    }
  }

  void _resumeIdleCamera() {
    if (!_cameraSuspended) return;
    _cameraSuspended = false;
    _scheduleCameraInitialization();
  }

  Future<void> _disposeCurrentCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) await controller.dispose();
  }

  Future<void> _scheduleCameraInitialization({
    bool cycleCamera = false,
    bool refreshDevices = false,
  }) {
    if (_cameraSuspended) return Future<void>.value();
    final generation = ++_cameraGeneration;
    final initialization = _cameraOperations.initialize(
      () => _initializeCamera(
        generation: generation,
        cycleCamera: cycleCamera,
        refreshDevices: refreshDevices,
      ),
    );
    if (mounted) {
      setState(() {
        _cameraError = null;
        _cameraInit = initialization;
      });
      initialization.whenComplete(() {
        if (mounted && generation == _cameraGeneration) setState(() {});
      });
    } else {
      _cameraInit = initialization;
    }
    return initialization;
  }

  Future<void> _initializeCamera({
    required int generation,
    required bool cycleCamera,
    required bool refreshDevices,
  }) async {
    try {
      await _disposeCurrentCamera();
      if (kIsWeb) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (!mounted || generation != _cameraGeneration || _cameraSuspended) {
        return;
      }
      if (!kIsWeb) {
        final camera = await Permission.camera.request();
        final microphone = await Permission.microphone.request();
        if (!camera.isGranted || !microphone.isGranted) {
          if (mounted && generation == _cameraGeneration) {
            setState(() {
              _cameraError = recordingCameraErrorMessage(
                'CameraAccessDenied',
                null,
              );
            });
          }
          return;
        }
      }
      final discoveredDevices = refreshDevices || _cameras.isEmpty;
      final cameras = discoveredDevices ? await availableCameras() : _cameras;
      if (cameras.isEmpty) {
        if (mounted && generation == _cameraGeneration) {
          setState(() {
            _cameraError = recordingCameraErrorMessage('cameraNotFound', null);
          });
        }
        return;
      }
      _cameras = cameras;
      // camera_web briefly opens every video input while discovering devices.
      // Give Chrome time to release those temporary tracks before requesting
      // the combined camera/microphone stream used for recording.
      if (kIsWeb && discoveredDevices) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (cycleCamera) {
        _selectedCameraIndex = (_selectedCameraIndex + 1) % cameras.length;
      } else if (_selectedCameraIndex >= cameras.length) {
        _selectedCameraIndex = 0;
        _hasSelectedPreferredCamera = false;
      }
      if (!_hasSelectedPreferredCamera) {
        final frontIndex = cameras.indexWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
        );
        if (frontIndex >= 0) _selectedCameraIndex = frontIndex;
        _hasSelectedPreferredCamera = true;
      }

      CameraException? finalError;
      for (var attempt = 0; attempt < 2; attempt++) {
        if (!mounted || generation != _cameraGeneration || _cameraSuspended) {
          return;
        }
        final controller = CameraController(
          cameras[_selectedCameraIndex],
          ResolutionPreset.medium,
          enableAudio: true,
        );
        _cameraController = controller;
        try {
          await controller.initialize();
          if (!mounted || generation != _cameraGeneration || _cameraSuspended) {
            if (identical(_cameraController, controller)) {
              _cameraController = null;
            }
            await controller.dispose();
            return;
          }
          setState(() => _cameraError = null);
          return;
        } on CameraException catch (error) {
          debugPrint(
            'Camera initialization failed '
            '(attempt ${attempt + 1}): ${error.code} ${error.description}',
          );
          finalError = error;
          if (identical(_cameraController, controller)) {
            _cameraController = null;
          }
          await controller.dispose();
          if (error.code != 'cameraNotReadable' || attempt > 0) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      if (finalError != null) throw finalError;
    } on CameraException catch (error) {
      await _disposeCurrentCamera();
      if (mounted && generation == _cameraGeneration) {
        setState(() {
          _cameraError = recordingCameraErrorMessage(
            error.code,
            error.description,
          );
        });
      }
    } catch (_) {
      await _disposeCurrentCamera();
      if (mounted && generation == _cameraGeneration) {
        setState(() => _cameraError = 'Camera could not be opened.');
      }
    }
  }

  void _retryCamera({bool cycleCamera = false}) {
    if (!mounted || _cameraOperations.isInitializing) return;
    final refreshDevices = _cameraError != null && !cycleCamera;
    _scheduleCameraInitialization(
      cycleCamera: cycleCamera,
      refreshDevices: refreshDevices,
    );
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
                              isInitializing: _cameraOperations.isInitializing,
                              height: previewHeight,
                              onRetry: _cameraOperations.isInitializing
                                  ? null
                                  : _retryCamera,
                              onSwitchCamera:
                                  _cameras.length > 1 &&
                                      !_cameraOperations.isInitializing
                                  ? () => _retryCamera(cycleCamera: true)
                                  : null,
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
  final bool isInitializing;
  final double height;
  final VoidCallback? onRetry;
  final VoidCallback? onSwitchCamera;

  const _CameraPresence({
    required this.controller,
    required this.cameraInit,
    required this.cameraError,
    required this.progress,
    required this.isRecording,
    required this.isPaused,
    required this.isReceived,
    required this.isInitializing,
    required this.height,
    required this.onRetry,
    required this.onSwitchCamera,
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
                  isInitializing: isInitializing,
                  onRetry: onRetry,
                  onSwitchCamera: onSwitchCamera,
                ),
                CustomPaint(
                  painter: _CameraPresencePainter(
                    progress: progress,
                    isRecording: isRecording,
                    isReceived: isReceived,
                  ),
                ),
                if (cameraError == null)
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
  final bool isInitializing;
  final VoidCallback? onRetry;
  final VoidCallback? onSwitchCamera;

  const _CameraPreviewLayer({
    required this.controller,
    required this.cameraInit,
    required this.cameraError,
    required this.isInitializing,
    required this.onRetry,
    required this.onSwitchCamera,
  });

  @override
  Widget build(BuildContext context) {
    if (cameraError != null) {
      return Container(
        color: AppColors.royalBlue.withValues(alpha: 0.35),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              cameraError!,
              style: AppTextStyles.body(
                fontSize: 13,
                color: AppColors.shellstone.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: isInitializing
                  ? const SizedBox.square(
                      dimension: 15,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : const Icon(Icons.refresh_rounded, size: 17),
              label: Text(
                'Retry camera',
                style: AppTextStyles.mono(fontSize: 10),
              ),
            ),
            if (onSwitchCamera != null)
              TextButton.icon(
                onPressed: onSwitchCamera,
                icon: const Icon(Icons.cameraswitch_outlined, size: 17),
                label: Text(
                  'Try another camera',
                  style: AppTextStyles.mono(fontSize: 10),
                ),
              ),
          ],
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
