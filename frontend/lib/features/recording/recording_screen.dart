import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/solenne_button.dart';
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
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.no_photography_outlined, size: 64),
              const SizedBox(height: 18),
              Text(
                'Camera access is needed',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              const Text(
                'Enable camera and microphone permissions to record a reflection.',
              ),
              const SizedBox(height: 18),
              SolenneButton(
                label: 'Open Settings',
                icon: Icons.settings_rounded,
                onPressed: openAppSettings,
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: controller == null || !controller.value.isInitialized
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error ?? 'Preparing camera...',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
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
            Positioned(
              top: 18,
              left: 18,
              right: 18,
              child: Column(
                children: [
                  Text(
                    _prompt,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  if (_isRecording)
                    Chip(
                      avatar: const Icon(
                        Icons.fiber_manual_record,
                        color: AppColors.danger,
                        size: 16,
                      ),
                      label: Text(_formatTime(_elapsed)),
                    ),
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
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording
                            ? AppColors.danger
                            : AppColors.mutedTeal,
                        border: Border.all(color: Colors.white, width: 5),
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
