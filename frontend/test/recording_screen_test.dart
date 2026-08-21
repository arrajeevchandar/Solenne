import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:solenne_frontend/features/recording/camera_operation_queue.dart';
import 'package:solenne_frontend/screens/recording/recording_screen.dart';

void main() {
  test('completion actions become visible once recording is paused', () {
    expect(
      recordingCompletionActionsVisible(isPaused: true, isReceived: false),
      isTrue,
    );

    expect(
      recordingCompletionActionsVisible(isPaused: false, isReceived: true),
      isTrue,
    );
  });

  test('completion actions stay hidden before and during recording', () {
    expect(
      recordingCompletionActionsVisible(isPaused: false, isReceived: false),
      isFalse,
    );
  });

  test('camera errors provide actionable recovery messages', () {
    expect(
      recordingCameraErrorMessage('cameraNotReadable', null),
      contains('camera or microphone stream'),
    );
    expect(
      recordingCameraErrorMessage('CameraAccessDenied', null),
      contains('Allow access'),
    );
    expect(
      recordingCameraErrorMessage('unknown', 'Device failed'),
      'Device failed',
    );
  });

  test(
    'web ignores Flutter lifecycle events from browser permission prompts',
    () {
      expect(recordingUsesFlutterLifecycle(isWeb: true), isFalse);
      expect(recordingUsesFlutterLifecycle(isWeb: false), isTrue);
    },
  );

  test('camera initialization is single-flight', () async {
    final queue = CameraOperationQueue();
    var calls = 0;
    final release = Completer<void>();

    final first = queue.initialize(() async {
      calls++;
      await release.future;
    });
    final second = queue.initialize(() async => calls++);

    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    release.complete();
    await first;
    expect(queue.isInitializing, isFalse);
  });

  test(
    'cancelled initialization allows a replacement after queued cleanup',
    () async {
      final queue = CameraOperationQueue();
      final events = <String>[];
      final firstRelease = Completer<void>();

      final first = queue.initialize(() async {
        events.add('first');
        await firstRelease.future;
      });
      queue.cancelInitialization();
      final cleanup = queue.enqueue(() async => events.add('cleanup'));
      final replacement = queue.initialize(
        () async => events.add('replacement'),
      );

      firstRelease.complete();
      await Future.wait([first, cleanup, replacement]);
      expect(events, ['first', 'cleanup', 'replacement']);
    },
  );
}
