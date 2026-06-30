import 'package:camera/camera.dart';

class RecordingDraft {
  const RecordingDraft({
    required this.file,
    required this.durationSeconds,
    required this.prompt,
  });

  final XFile file;
  final int durationSeconds;
  final String prompt;
}
