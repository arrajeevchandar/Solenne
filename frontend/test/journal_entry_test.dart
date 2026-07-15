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

  test('preserves complete AI insight metadata', () {
    final insight = AiInsight.fromMap({
      'title': 'A steadier pace',
      'summary': 'Your pace sounded more settled today.',
      'moodLabel': 'grounded',
      'dayThemes': ['rest', 42, ''],
      'suggestions': ['Leave a little room tonight.'],
      'reflectionQuestions': ['What helped you slow down?'],
      'evidence': {
        'metrics': {'pauseRatio': 0.42},
        'journalIds': ['journal-1'],
      },
      'confidence': 0.78,
      'safetyNote': 'This is a reflection, not a diagnosis.',
    });

    expect(insight.dayThemes, ['rest', '42']);
    expect(insight.evidence['metrics'], {'pauseRatio': 0.42});
    expect(insight.toMap()['evidence'], insight.evidence);
    expect(insight.confidence, 0.78);
  });

  test('derives a Cloudinary poster for legacy entries', () {
    final entry = JournalEntry(
      id: 'journal-2',
      userId: 'user-1',
      prompt: 'What changed today?',
      recordedAt: DateTime(2026, 6, 30, 18),
      durationSeconds: 42,
      cloudinaryPublicId: 'solenne/journals/journal-2',
      videoUrl:
          'https://res.cloudinary.com/demo/video/upload/v123/solenne/journals/journal-2.mp4',
      thumbnailUrl: '',
      uploadStatus: 'saved',
      analysisStatus: 'not_started',
    );

    expect(entry.effectiveThumbnailUrl, contains('/video/upload/so_0,f_jpg/'));
    expect(entry.effectiveThumbnailUrl, endsWith('/journal-2.jpg'));
    expect(entry.hasImageThumbnail, isTrue);
  });
}
