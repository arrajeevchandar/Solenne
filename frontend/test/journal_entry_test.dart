import 'package:flutter_test/flutter_test.dart';
import 'package:solenne_frontend/features/journals/journal_entry.dart';

void main() {
  test('serializes journal metadata for Firestore', () {
    final entry = JournalEntry(
      id: 'journal-1',
      userId: 'user-1',
      prompt: 'What changed today?',
      recordedAt: DateTime(2026, 6, 30, 18),
      durationSeconds: 42,
      cloudinaryPublicId: 'solenne/journals/journal-1',
      videoUrl: 'https://example.com/video.mp4',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      uploadStatus: 'saved',
      analysisStatus: 'not_started',
    );

    final data = entry.toFirestore();

    expect(data['id'], 'journal-1');
    expect(data['userId'], 'user-1');
    expect(data['uploadStatus'], 'saved');
    expect(data['analysisStatus'], 'not_started');
    expect(data['durationSeconds'], 42);
  });
}
