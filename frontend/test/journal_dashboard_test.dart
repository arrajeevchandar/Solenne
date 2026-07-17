import 'package:flutter_test/flutter_test.dart';
import 'package:solenne_frontend/features/journals/journal_dashboard.dart';
import 'package:solenne_frontend/features/journals/journal_entry.dart';

void main() {
  test('computes live session, week, and consecutive-day values', () {
    final now = DateTime(2026, 7, 15);
    final dashboard = JournalDashboard([
      _entry('today', DateTime(2026, 7, 15)),
      _entry('yesterday', DateTime(2026, 7, 14)),
      _entry('two-days', DateTime(2026, 7, 13)),
      _entry('older', DateTime(2026, 7, 5)),
    ], now: now);

    expect(dashboard.sessions, 4);
    expect(dashboard.streak, 3);
    expect(dashboard.thisWeek, 3);
  });

  test('uses completed backend analysis for reflections and weather', () {
    final dashboard = JournalDashboard([
      _entry(
        'latest',
        DateTime(2026, 7, 15),
        status: 'complete',
        valence: 0.6,
        insight: const AiInsight(
          title: 'A steadier day',
          summary: 'Your reflection centered on making room to pause.',
          moodLabel: 'grounded',
          suggestions: ['Keep one quiet margin tomorrow.'],
          dayThemes: ['rest'],
        ),
      ),
      _entry(
        'previous',
        DateTime(2026, 7, 14),
        status: 'complete',
        valence: 0.1,
      ),
    ], now: DateTime(2026, 7, 15));

    expect(dashboard.reflectionText, contains('making room'));
    expect(dashboard.weatherText, contains('brighter'));
    expect(dashboard.latestSuggestion, contains('quiet margin'));
    expect(dashboard.recurringThemes.first.key, 'rest');
  });
}

JournalEntry _entry(
  String id,
  DateTime recordedAt, {
  String status = 'queued',
  double? valence,
  AiInsight? insight,
}) {
  return JournalEntry(
    id: id,
    userId: 'user-1',
    prompt: 'How was today?',
    recordedAt: recordedAt,
    durationSeconds: 60,
    cloudinaryPublicId: id,
    videoUrl: '',
    thumbnailUrl: '',
    uploadStatus: 'saved',
    analysisStatus: status,
    fused: valence == null ? const {} : {'overallValence': valence},
    aiInsights: insight == null ? const [] : [insight],
  );
}
