import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solenne_frontend/features/journals/journal_entry.dart';
import 'package:solenne_frontend/features/journals/journal_repository.dart';
import 'package:solenne_frontend/screens/insights/daily_insight_screen.dart';
import 'package:solenne_frontend/theme/app_theme.dart';

void main() {
  testWidgets('shows the saved video area with an honest pending state', (
    tester,
  ) async {
    final entry = _entry(analysisStatus: 'not_started');

    await tester.pumpWidget(_app(entry));
    await tester.pumpAndSettle();

    expect(find.text('Evening reflection'), findsOneWidget);
    expect(find.text('QUEUED FOR ANALYSIS'), findsOneWidget);
    expect(find.text('Your reflection is saved.'), findsOneWidget);
    expect(find.textContaining('private analysis worker'), findsOneWidget);
    expect(find.text('Transcript is being prepared'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('opens the completed transcript in a styled sheet', (
    tester,
  ) async {
    final entry = _entry(
      analysisStatus: 'complete',
      transcript: const JournalTranscript(
        text: 'I made space for a slower evening.',
        wordCount: 7,
        language: 'en',
        confidence: 0.94,
      ),
    );

    await tester.pumpWidget(_app(entry));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Show transcript'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show transcript'));
    await tester.pumpAndSettle();

    expect(find.text('Your words'), findsOneWidget);
    expect(find.text('EN · 7 WORDS'), findsOneWidget);
    expect(find.text('I made space for a slower evening.'), findsOneWidget);
  });

  testWidgets('renders all AI insight fields and expandable evidence', (
    tester,
  ) async {
    final entry = _entry(
      analysisStatus: 'complete',
      insights: const [
        AiInsight(
          title: 'A steadier pace',
          summary: 'Your voice carried a calmer rhythm today.',
          moodLabel: 'grounded',
          dayThemes: ['rest', 'clarity'],
          suggestions: ['Keep one small margin in the evening.'],
          reflectionQuestions: ['What made the day feel more spacious?'],
          confidence: 0.82,
          safetyNote: 'Treat this as a gentle observation, not a diagnosis.',
          evidence: {
            'metrics': {'pauseRatio': 0.42},
          },
        ),
      ],
    );

    await tester.pumpWidget(_app(entry));
    await tester.pumpAndSettle();

    expect(find.text('A steadier pace'), findsOneWidget);
    expect(
      find.text('Your voice carried a calmer rhythm today.'),
      findsOneWidget,
    );
    expect(find.text('rest'), findsOneWidget);
    expect(find.text('Keep one small margin in the evening.'), findsOneWidget);
    expect(find.text('What made the day feel more spacious?'), findsOneWidget);
    expect(
      find.text('Treat this as a gentle observation, not a diagnosis.'),
      findsOneWidget,
    );
    expect(find.text('82%'), findsOneWidget);

    await tester.ensureVisible(find.text('WHY THIS APPEARED'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WHY THIS APPEARED'));
    await tester.pumpAndSettle();
    expect(find.text('METRICS / PAUSE RATIO'), findsOneWidget);
    expect(find.text('0.42'), findsOneWidget);
  });
}

Widget _app(JournalEntry entry) {
  return ProviderScope(
    overrides: [
      journalByIdStreamProvider.overrideWith(
        (ref, entryId) => Stream.value(entry),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: DailyInsightScreen(entryId: entry.id),
    ),
  );
}

JournalEntry _entry({
  required String analysisStatus,
  List<AiInsight> insights = const [],
  JournalTranscript transcript = const JournalTranscript(),
}) {
  return JournalEntry(
    id: 'entry-1',
    userId: 'user-1',
    title: 'Evening reflection',
    prompt: 'What felt different today?',
    recordedAt: DateTime(2026, 7, 15, 19, 30),
    durationSeconds: 95,
    cloudinaryPublicId: 'solenne/journals/entry-1',
    videoUrl: '',
    thumbnailUrl: '',
    uploadStatus: 'saved',
    analysisStatus: analysisStatus,
    transcript: transcript,
    moodLabel: 'grounded',
    aiInsights: insights,
  );
}
