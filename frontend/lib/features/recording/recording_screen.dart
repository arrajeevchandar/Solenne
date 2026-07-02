import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/organic_background.dart';
import '../../core/widgets/solenne_button.dart';
import '../../core/widgets/solenne_card.dart';
import '../../core/widgets/solenne_visuals.dart';
import 'recording_draft.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  static const _maxSeconds = 180;
  static const _prompt = 'What is one moment from today you want to remember?';

  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _permissionDenied = false;
  bool _isRecording = false;
  int _elapsed = 0;
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final camera = await Permission.camera.request();
      final mic = await Permission.microphone.request();
      if (!camera.isGranted || !mic.isGranted) {
        setState(() => _permissionDenied = true);
        return;
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No camera was found on this device.');
        return;
      }
      final front = cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      _cameras = cameras;
      _cameraIndex = front >= 0 ? front : 0;
      await _setCamera(_cameraIndex);
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _setCamera(int index) async {
    try {
      await _controller?.dispose();
      final controller = CameraController(
        _cameras[index],
        ResolutionPreset.high,
        enableAudio: true,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _error = null;
      });
    } on CameraException catch (error) {
      setState(() => _error = _cameraErrorMessage(error));
    } on PlatformException catch (error) {
      setState(() => _error = error.message ?? error.code);
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _start() async {
    final controller = _controller;
    if (controller == null || _isRecording) return;
    try {
      await controller.startVideoRecording();
      setState(() {
        _isRecording = true;
        _elapsed = 0;
        _error = null;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
        if (!mounted) return;
        if (_elapsed + 1 >= _maxSeconds) {
          await _stop();
        } else {
          setState(() => _elapsed++);
        }
      });
    } on CameraException catch (error) {
      setState(() => _error = _cameraErrorMessage(error));
    } on PlatformException catch (error) {
      setState(() => _error = error.message ?? error.code);
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _stop() async {
    final controller = _controller;
    if (controller == null || !_isRecording) return;
    _timer?.cancel();
    try {
      final file = await controller.stopVideoRecording();
      setState(() => _isRecording = false);
      if (!mounted) return;
      context.go(
        '/record/preview',
        extra: RecordingDraft(
          file: file,
          durationSeconds: _elapsed.clamp(1, _maxSeconds),
          prompt: _prompt,
        ),
      );
    } on CameraException catch (error) {
      setState(() {
        _isRecording = false;
        _error = _cameraErrorMessage(error);
      });
    } on PlatformException catch (error) {
      setState(() {
        _isRecording = false;
        _error = error.message ?? error.code;
      });
    } catch (error) {
      setState(() {
        _isRecording = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _flip() async {
    if (_cameras.length < 2 || _isRecording) return;
    final next = (_cameraIndex + 1) % _cameras.length;
    _cameraIndex = next;
    await _setCamera(next);
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return Scaffold(
        body: OrganicBackground(
          showGrid: true,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SolenneLogoOrb(size: 104),
                  const SizedBox(height: 22),
                  Text(
                    'Camera access is needed',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Enable camera and microphone permissions to record a reflection.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  SolenneButton(
                    label: 'Open Settings',
                    icon: Icons.settings_rounded,
                    onPressed: openAppSettings,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final controller = _controller;
    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: controller == null || !controller.value.isInitialized
                  ? OrganicBackground(
                      showGrid: true,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SolenneLogoOrb(size: 92),
                              const SizedBox(height: 18),
                              Text(
                                _error ?? 'Preparing camera...',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : CameraPreview(controller),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.5),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _RecordingGridPainter()),
              ),
            ),
            Positioned(
              top: 18,
              left: 18,
              right: 18,
              child: Column(
                children: [
                  SolenneCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.aqua,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _prompt,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    _formatTime(_elapsed),
                    style: GoogleFonts.dmMono(
                      color: AppColors.textPrimary,
                      fontSize: 58,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SolenneStatusChip(
                    label: _isRecording ? 'Recording - max 03:00' : 'Ready',
                    color: _isRecording ? AppColors.coral : AppColors.aqua,
                    icon: _isRecording
                        ? Icons.fiber_manual_record
                        : Icons.videocam_outlined,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    SolenneCard(
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.coral),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 28,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filledTonal(
                    onPressed: _isRecording ? null : () => context.go('/home'),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  GestureDetector(
                    onTap: _isRecording ? _stop : _start,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording ? AppColors.coral : AppColors.aqua,
                        border: Border.all(
                          color: AppColors.textPrimary,
                          width: 5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_isRecording
                                        ? AppColors.coral
                                        : AppColors.aqua)
                                    .withValues(alpha: 0.40),
                            blurRadius: 34,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRecording
                            ? Icons.stop_rounded
                            : Icons.videocam_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _flip,
                    icon: const Icon(Icons.cameraswitch_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }

  String _cameraErrorMessage(CameraException error) {
    if (error.code == 'notSupported') {
      return 'Video recording is not supported by this browser. Use Chrome on '
          'desktop or the Android app.';
    }
    if (error.code.toLowerCase().contains('permission')) {
      return 'Camera and microphone permission are required to record.';
    }
    return error.description ?? error.code;
  }
}

class _RecordingGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gridLine
      ..strokeWidth = 1;
    const gap = 34.0;
    for (double x = 0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
