import 'package:flutter_test/flutter_test.dart';
import 'package:solenne_frontend/features/archive/archive_repository.dart';
import 'package:solenne_frontend/features/journals/journal_entry.dart';

void main() {
  group('ArchiveExportPolicy', () {
    test('deduplicates selections and caps one export at 50 sessions', () {
      final ids = [
        'journal-0',
        'journal-0',
        ...List.generate(60, (index) => 'journal-${index + 1}'),
      ];

      final selected = ArchiveExportPolicy.normalizeSelection(ids);

      expect(selected, hasLength(50));
      expect(selected.toSet(), hasLength(50));
      expect(selected.first, 'journal-0');
    });

    test('allows partial both exports while transcript-only needs text', () {
      final audioOnly = _entry(
        videoUrl: 'https://res.cloudinary.com/demo/video/upload/entry.mp4',
      );
      final transcriptOnly = _entry(
        transcript: const JournalTranscript(
          text: 'A saved transcript.',
          wordCount: 3,
        ),
      );

      expect(
        ArchiveExportPolicy.hasRequestedContent(
          audioOnly,
          ExportKind.transcript,
        ),
        isFalse,
      );
      expect(
        ArchiveExportPolicy.hasRequestedContent(audioOnly, ExportKind.both),
        isTrue,
      );
      expect(
        ArchiveExportPolicy.hasRequestedContent(
          transcriptOnly,
          ExportKind.audio,
        ),
        isFalse,
      );
      expect(
        ArchiveExportPolicy.hasRequestedContent(
          transcriptOnly,
          ExportKind.transcript,
        ),
        isTrue,
      );
    });
  });
}

JournalEntry _entry({
  String videoUrl = '',
  JournalTranscript transcript = const JournalTranscript(),
}) {
  return JournalEntry(
    id: 'journal-1',
    userId: 'user-1',
    prompt: 'Daily reflection',
    recordedAt: DateTime(2026, 7, 30),
    durationSeconds: 30,
    cloudinaryPublicId: '',
    videoUrl: videoUrl,
    thumbnailUrl: '',
    uploadStatus: 'saved',
    analysisStatus: 'complete',
    transcript: transcript,
  );
}
