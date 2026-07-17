import 'dart:math' as math;

import 'journal_entry.dart';

class JournalDashboard {
  JournalDashboard(Iterable<JournalEntry> source, {DateTime? now})
    : now = _dateOnly(now ?? DateTime.now()),
      entries = List.unmodifiable(
        [...source]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt)),
      );

  final DateTime now;
  final List<JournalEntry> entries;

  List<JournalEntry> get analyzedEntries => entries
      .where((entry) => entry.analysisStatus == 'complete')
      .toList(growable: false);

  int get sessions => entries.length;

  int get thisWeek {
    final start = now.subtract(Duration(days: now.weekday - DateTime.monday));
    return _distinctDates(
      entries.where((entry) => !_dateOnly(entry.recordedAt).isBefore(start)),
    ).length;
  }

  int get streak {
    final days = _distinctDates(entries);
    if (days.isEmpty) return 0;
    var cursor = now;
    if (!days.contains(cursor)) {
      final yesterday = now.subtract(const Duration(days: 1));
      if (!days.contains(yesterday)) return 0;
      cursor = yesterday;
    }
    var count = 0;
    while (days.contains(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  JournalEntry? get latestEntry => entries.isEmpty ? null : entries.first;

  JournalEntry? get latestAnalyzed =>
      analyzedEntries.isEmpty ? null : analyzedEntries.first;

  String get reflectionText {
    final latest = latestEntry;
    if (latest == null) {
      return 'Your first reflection will begin drawing this view.';
    }
    if (latest.analysisStatus == 'queued' ||
        latest.analysisStatus == 'processing') {
      return 'Your latest reflection is still settling into words.';
    }
    final analyzed = latestAnalyzed;
    if (analyzed?.aiInsights.isNotEmpty == true) {
      return analyzed!.aiInsights.first.summary;
    }
    return 'No reliable observation has surfaced yet.';
  }

  String get weatherText {
    final analyzed = analyzedEntries;
    if (analyzed.isEmpty) return 'Waiting for your first analyzed reflection.';
    final mood = _moodFor(analyzed.first);
    if (analyzed.length < 2) {
      return '${_capitalize(mood)}, from your latest entry.';
    }
    final current = metric(analyzed[0].fused, 'overallValence');
    final previous = metric(analyzed[1].fused, 'overallValence');
    if (current == null || previous == null) {
      return '${_capitalize(mood)}, from your latest entry.';
    }
    final difference = current - previous;
    final comparison = difference > 0.1
        ? 'a little brighter than the entry before.'
        : difference < -0.1
        ? 'a little heavier than the entry before.'
        : 'close to the rhythm of the entry before.';
    return '${_capitalize(mood)}, $comparison';
  }

  List<double> get valencePoints {
    final values = analyzedEntries
        .map((entry) => metric(entry.fused, 'overallValence'))
        .whereType<double>()
        .take(7)
        .map((value) => ((value + 1) / 2).clamp(0.0, 1.0))
        .toList()
        .reversed
        .toList(growable: false);
    return values;
  }

  List<double> get voiceEnergyPoints => _normalizedMetricPoints(
    analyzedEntries,
    (entry) => metric(entry.voice, 'energyMean'),
  );

  List<double> get outlookPoints => analyzedEntries
      .map((entry) => metric(entry.nlp, 'sentimentValence'))
      .whereType<double>()
      .take(5)
      .map((value) => ((value + 1) / 2).clamp(0.0, 1.0))
      .toList()
      .reversed
      .toList(growable: false);

  List<double> get stressPoints => analyzedEntries
      .map((entry) => metric(entry.nlp, 'stressScore'))
      .whereType<double>()
      .take(5)
      .map((value) => value.clamp(0.0, 1.0))
      .toList()
      .reversed
      .toList(growable: false);

  double? get latestVoiceEnergy => latestAnalyzed == null
      ? null
      : metric(latestAnalyzed!.voice, 'energyMean');

  double? get latestStress => latestAnalyzed == null
      ? null
      : metric(latestAnalyzed!.nlp, 'stressScore');

  double? get latestOutlook => latestAnalyzed == null
      ? null
      : metric(latestAnalyzed!.nlp, 'sentimentValence');

  String get latestSuggestion {
    for (final entry in analyzedEntries) {
      for (final insight in entry.aiInsights) {
        if (insight.suggestions.isNotEmpty) return insight.suggestions.first;
      }
    }
    return 'Keep recording; a grounded next step will appear here.';
  }

  List<String> get languageTerms {
    final counts = <String, int>{};
    for (final entry in analyzedEntries.take(14)) {
      final topics = _strings(entry.nlp['topics']);
      final phrases = _strings(entry.nlp['keyPhrases']);
      for (final value in [...topics, ...phrases]) {
        final normalized = value.replaceAll('_', ' ').trim().toLowerCase();
        if (normalized.isNotEmpty) {
          counts[normalized] = (counts[normalized] ?? 0) + 1;
        }
      }
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) {
        final count = b.value.compareTo(a.value);
        return count == 0 ? a.key.compareTo(b.key) : count;
      });
    return ranked.take(6).map((entry) => entry.key).toList(growable: false);
  }

  List<MapEntry<String, int>> get recurringThemes {
    final counts = <String, int>{};
    for (final entry in analyzedEntries.take(30)) {
      for (final insight in entry.aiInsights) {
        for (final theme in insight.dayThemes) {
          final normalized = theme.trim().toLowerCase();
          if (normalized.isNotEmpty) {
            counts[normalized] = (counts[normalized] ?? 0) + 1;
          }
        }
      }
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ranked.take(3).toList(growable: false);
  }

  static double? metric(Map<String, dynamic> block, String key) {
    final value = block[key];
    return value is num ? value.toDouble() : null;
  }

  static Set<DateTime> _distinctDates(Iterable<JournalEntry> source) {
    return source.map((entry) => _dateOnly(entry.recordedAt)).toSet();
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _moodFor(JournalEntry entry) {
    final direct = entry.moodLabel?.trim();
    if (direct?.isNotEmpty == true) return direct!;
    if (entry.aiInsights.isNotEmpty &&
        entry.aiInsights.first.moodLabel.trim().isNotEmpty) {
      return entry.aiInsights.first.moodLabel.trim();
    }
    return 'Reflective';
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  static List<String> _strings(Object? value) {
    if (value is! Iterable) return const [];
    return value.map((item) => item.toString()).toList(growable: false);
  }

  static List<double> _normalizedMetricPoints(
    Iterable<JournalEntry> source,
    double? Function(JournalEntry entry) read,
  ) {
    final values = source
        .map(read)
        .whereType<double>()
        .take(5)
        .toList()
        .reversed
        .toList();
    if (values.isEmpty) return const [];
    final minimum = values.reduce(math.min);
    final maximum = values.reduce(math.max);
    if ((maximum - minimum).abs() < 0.000001) {
      return List.filled(values.length, 0.5, growable: false);
    }
    return values
        .map(
          (value) => ((value - minimum) / (maximum - minimum)).clamp(0.0, 1.0),
        )
        .toList(growable: false);
  }
}
