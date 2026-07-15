import 'package:flutter_test/flutter_test.dart';
import 'package:solenne_frontend/features/journals/journal_day.dart';
import 'package:solenne_frontend/features/journals/journal_entry.dart';

void main() {
  test('groups entries by local calendar date and sorts newest first', () {
    final entries = [
      _entry('old-day', DateTime(2026, 7, 13, 22)),
      _entry('same-day-early', DateTime(2026, 7, 15, 8)),
      _entry('middle-day', DateTime(2026, 7, 14, 12)),
      _entry('same-day-late', DateTime(2026, 7, 15, 19)),
    ];

    final days = groupJournalEntries(entries);

    expect(days.map((day) => day.key), [
      '2026-07-15',
      '2026-07-14',
      '2026-07-13',
    ]);
    expect(days.first.entryCount, 2);
    expect(days.first.latestEntry.id, 'same-day-late');
    expect(days.first.entries.last.id, 'same-day-early');
  });

  test('date keys remain stable across month and year boundaries', () {
    expect(journalDateKey(DateTime(2026, 1, 2, 23, 59)), '2026-01-02');
    expect(journalDateKey(DateTime(2027, 12, 31)), '2027-12-31');
  });
}

JournalEntry _entry(String id, DateTime recordedAt) {
  return JournalEntry(
    id: id,
    userId: 'user-1',
    prompt: 'Daily reflection',
    recordedAt: recordedAt,
    durationSeconds: 60,
    cloudinaryPublicId: 'solenne/journals/$id',
    videoUrl: 'https://example.com/$id.mp4',
    thumbnailUrl: 'https://example.com/$id.jpg',
    uploadStatus: 'saved',
    analysisStatus: 'not_started',
  );
}
