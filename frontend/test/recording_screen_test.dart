import 'package:flutter_test/flutter_test.dart';
import 'package:solenne_frontend/screens/recording/recording_screen.dart';

void main() {
  test('completion actions become visible once recording is paused', () {
    expect(
      recordingCompletionActionsVisible(
        isPaused: true,
        isReceived: false,
      ),
      isTrue,
    );

    expect(
      recordingCompletionActionsVisible(
        isPaused: false,
        isReceived: true,
      ),
      isTrue,
    );
  });

  test('completion actions stay hidden before and during recording', () {
    expect(
      recordingCompletionActionsVisible(
        isPaused: false,
        isReceived: false,
      ),
      isFalse,
    );
  });
}
