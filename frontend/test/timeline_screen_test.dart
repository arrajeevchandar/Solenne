import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solenne_frontend/features/journals/journal_entry.dart';
import 'package:solenne_frontend/features/journals/journal_repository.dart';
import 'package:solenne_frontend/screens/timeline/timeline_screen.dart';
import 'package:solenne_frontend/theme/app_theme.dart';

void main() {
  testWidgets('timeline displays actual recorded-day metadata', (tester) async {
    final now = DateTime.now();
    final entry = JournalEntry(
      id: 'today-entry',
      userId: 'user-1',
      title: 'A real saved reflection',
      prompt: 'How was today?',
      recordedAt: DateTime(now.year, now.month, now.day, 18),
      durationSeconds: 80,
      cloudinaryPublicId: 'solenne/journals/today-entry',
      videoUrl: 'https://example.com/today-entry.mp4',
      thumbnailUrl: 'https://example.com/today-entry.jpg',
      uploadStatus: 'saved',
      analysisStatus: 'not_started',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalRangeStreamProvider.overrideWith(
            (ref, range) => Stream.value([entry]),
          ),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const TimelineScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('A real saved reflection'), findsOneWidget);
    expect(find.text('Saved reflection'), findsOneWidget);
  });
}
