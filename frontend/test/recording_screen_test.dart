import 'package:flutter_test/flutter_test.dart';
import 'package:solenne_frontend/screens/recording/recording_screen.dart';

void main() {
  test('completion actions remain visible after the entry is received', () {
    expect(
      recordingCompletionActionsVisible(
        isStopped: true,
        isReceived: false,
      ),
      isTrue,
    );

    expect(
      recordingCompletionActionsVisible(
        isStopped: false,
        isReceived: true,
      ),
      isTrue,
    );
  });

  test('completion actions stay hidden before and during recording', () {
    expect(
      recordingCompletionActionsVisible(
        isStopped: false,
        isReceived: false,
      ),
      isFalse,
    );
  });
}
