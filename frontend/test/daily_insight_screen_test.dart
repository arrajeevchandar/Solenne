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

  testWidgets('queued reanalysis hides stale prior insights', (tester) async {
    final entry = _entry(
      analysisStatus: 'queued',
      insights: const [
        AiInsight(
          title: 'Old insight',
          summary: 'This result belongs to the previous analysis run.',
          moodLabel: 'reflective',
        ),
      ],
    );

    await tester.pumpWidget(_app(entry));
    await tester.pumpAndSettle();

    expect(find.text('INSIGHTS ARE STILL SETTLING'), findsOneWidget);
    expect(find.text('Old insight'), findsNothing);
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

  testWidgets('explains legacy evidence and hides transcript and run ID', (
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
            'transcript': 'This raw transcript must not be repeated here.',
            'runId': '1784270734328000',
            'metrics': {
              'pauseRatio': 0.42,
              'overallArousal': 0.34,
              'congruence': 0.79,
              'overallValence': 0.5,
            },
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
    expect(find.text('82%'), findsNothing);

    await tester.ensureVisible(find.text('WHY THIS APPEARED'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WHY THIS APPEARED'));
    await tester.pumpAndSettle();
    expect(find.text('REASON FOR THIS INSIGHT'), findsOneWidget);
    expect(
      find.textContaining(
        'The combined language, voice, and visual tone leaned more positive.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'The available words, voice, and visual tone were broadly aligned.',
      ),
      findsOneWidget,
    );
    expect(find.text('SIGNALS USED'), findsNothing);
    expect(find.text('42%'), findsNothing);
    expect(find.text('34%'), findsNothing);
    expect(find.text('79%'), findsNothing);
    expect(find.text('+0.50'), findsNothing);
    expect(
      find.text('This raw transcript must not be repeated here.'),
      findsNothing,
    );
    expect(find.text('1784270734328000'), findsNothing);
    expect(find.textContaining('RUN ID'), findsNothing);
  });

  testWidgets('renders source-supported reasoning without paper metadata', (
    tester,
  ) async {
    final entry = _entry(
      analysisStatus: 'complete',
      insights: const [
        AiInsight(
          title: 'Work was present',
          summary: 'Work and a deadline appeared in this reflection.',
          moodLabel: 'reflective',
          suggestions: ['Take one short pause away from the task.'],
          confidence: 0.8,
          safetyNote:
              'Solenne offers wellness reflections, not medical advice.',
          evidence: {
            'schemaVersion': 2,
            'rationale':
                'Work and a deadline were both named in the reflection, so the insight focuses on making space around that pressure.',
            'userEvidence': [
              {
                'evidenceId': 'fact-work',
                'label': 'Theme present in this reflection',
                'value': 'work',
                'sourcePath': 'nlp.topics',
                'journalIds': ['entry-1'],
                'confidence': 0.9,
              },
            ],
            'externalReferences': [
              {
                'claimCardId': 'claim-work',
                'sourceId': 'source-work',
                'title': 'Reviewed work-break source',
                'publisher': 'Example Journal',
                'year': 2024,
                'url': 'https://example.org/work-breaks',
                'doi': null,
                'pmid': null,
                'matchedClaim': 'Work-break research studies brief pauses.',
                'limitations': 'General context only.',
                'supportLevel': 'moderate',
              },
            ],
            'verification': {
              'status': 'source_supported',
              'method': 'curated_claim_match',
              'catalogVersion': 'test-v1',
              'reason': null,
            },
          },
        ),
      ],
    );

    await tester.pumpWidget(_app(entry));
    await tester.pumpAndSettle();

    expect(find.text('SOURCE-SUPPORTED'), findsOneWidget);
    await tester.ensureVisible(find.text('WHY THIS APPEARED'));
    await tester.tap(find.text('WHY THIS APPEARED'));
    await tester.pumpAndSettle();
    expect(find.text('REASON FOR THIS INSIGHT'), findsOneWidget);
    expect(
      find.text(
        'Work and a deadline were both named in the reflection, so the insight focuses on making space around that pressure.',
      ),
      findsOneWidget,
    );
    expect(find.text('FROM YOUR REFLECTION'), findsOneWidget);
    expect(find.text('PUBLIC RESEARCH CONTEXT'), findsNothing);
    expect(find.text('Reviewed work-break source'), findsNothing);
    expect(find.textContaining('General context only.'), findsNothing);
    expect(find.text('OPEN SOURCE'), findsNothing);
  });

  testWidgets('shows a grounded rationale without evidence rows', (
    tester,
  ) async {
    final entry = _entry(
      analysisStatus: 'complete',
      insights: const [
        AiInsight(
          title: 'A clear thread',
          summary: 'One concern appeared repeatedly in this reflection.',
          moodLabel: 'reflective',
          evidence: {
            'schemaVersion': 2,
            'rationale':
                'The same concern appeared in several parts of the reflection, which made it the clearest thread to carry forward.',
            'userEvidence': [],
            'externalReferences': [],
            'verification': {
              'status': 'user_data_only',
              'method': 'personal_evidence',
              'catalogVersion': null,
              'reason': null,
            },
          },
        ),
      ],
    );

    await tester.pumpWidget(_app(entry));
    await tester.pumpAndSettle();

    expect(find.text('BASED ON THIS JOURNAL'), findsOneWidget);
    await tester.ensureVisible(find.text('WHY THIS APPEARED'));
    await tester.tap(find.text('WHY THIS APPEARED'));
    await tester.pumpAndSettle();

    expect(find.text('REASON FOR THIS INSIGHT'), findsOneWidget);
    expect(
      find.text(
        'The same concern appeared in several parts of the reflection, which made it the clearest thread to carry forward.',
      ),
      findsOneWidget,
    );
    expect(find.text('FROM YOUR REFLECTION'), findsNothing);
    expect(find.text('PUBLIC RESEARCH CONTEXT'), findsNothing);
  });

  testWidgets('safety bypass hides mood confidence and ordinary evidence', (
    tester,
  ) async {
    final entry = _entry(
      analysisStatus: 'complete',
      insights: const [
        AiInsight(
          title: 'You deserve immediate support',
          summary: 'Please contact immediate local help.',
          moodLabel: 'heavy',
          suggestions: ['This must stay hidden.'],
          reflectionQuestions: ['This must also stay hidden?'],
          confidence: 0.99,
          safetyNote: 'Solenne is not an emergency service.',
          evidence: {
            'schemaVersion': 2,
            'rationale': 'This safety rationale must stay hidden.',
            'userEvidence': [],
            'externalReferences': [],
            'verification': {
              'status': 'fallback',
              'method': 'deterministic_safety_bypass',
              'catalogVersion': null,
              'reason': 'safety_bypass',
            },
          },
        ),
      ],
    );

    await tester.pumpWidget(_app(entry));
    await tester.pumpAndSettle();

    expect(find.text('SUPPORT FIRST'), findsOneWidget);
    expect(find.text('SIGNAL CONFIDENCE'), findsNothing);
    expect(find.text('heavy'), findsNothing);
    expect(find.text('This must stay hidden.'), findsNothing);
    expect(find.text('This must also stay hidden?'), findsNothing);
    expect(find.text('This safety rationale must stay hidden.'), findsNothing);
    expect(find.text('WHY THIS APPEARED'), findsNothing);
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
