import 'journal_entry.dart';

class JournalDay {
  JournalDay({required DateTime date, required List<JournalEntry> entries})
    : assert(entries.isNotEmpty, 'A journal day must contain an entry.'),
      date = DateTime(date.year, date.month, date.day),
      entries = List.unmodifiable(
        [...entries]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt)),
      );

  final DateTime date;
  final List<JournalEntry> entries;

  JournalEntry get latestEntry => entries.first;
  int get entryCount => entries.length;
  String get key => journalDateKey(date);
}

List<JournalDay> groupJournalEntries(Iterable<JournalEntry> entries) {
  final grouped = <String, List<JournalEntry>>{};
  final dates = <String, DateTime>{};

  for (final entry in entries) {
    final date = DateTime(
      entry.recordedAt.year,
      entry.recordedAt.month,
      entry.recordedAt.day,
    );
    final key = journalDateKey(date);
    dates[key] = date;
    grouped.putIfAbsent(key, () => <JournalEntry>[]).add(entry);
  }

  final days = grouped.entries
      .map((group) => JournalDay(date: dates[group.key]!, entries: group.value))
      .toList();
  days.sort((a, b) => b.date.compareTo(a.date));
  return days;
}

String journalDateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
