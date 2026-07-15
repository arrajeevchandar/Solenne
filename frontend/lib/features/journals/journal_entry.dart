import 'package:cloud_firestore/cloud_firestore.dart';

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.userId,
    required this.prompt,
    required this.recordedAt,
    required this.durationSeconds,
    required this.cloudinaryPublicId,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.uploadStatus,
    required this.analysisStatus,
    this.analysisStep = '',
    this.analysisVersion = '',
    this.analysisError,
    this.analysisStartedAt,
    this.analysisCompletedAt,
    this.transcript = const JournalTranscript(),
    this.facial = const {},
    this.voice = const {},
    this.nlp = const {},
    this.fused = const {},
    this.templateInsights = const [],
    this.insightProvider = '',
    this.llmDiagnostics = const {},
    this.title = '',
    this.moodLabel,
    this.aiInsights = const [],
  });

  final String id;
  final String userId;
  final String prompt;
  final DateTime recordedAt;
  final int durationSeconds;
  final String cloudinaryPublicId;
  final String videoUrl;
  final String thumbnailUrl;
  final String uploadStatus;
  final String analysisStatus;
  final String analysisStep;
  final String analysisVersion;
  final String? analysisError;
  final DateTime? analysisStartedAt;
  final DateTime? analysisCompletedAt;
  final JournalTranscript transcript;
  final Map<String, dynamic> facial;
  final Map<String, dynamic> voice;
  final Map<String, dynamic> nlp;
  final Map<String, dynamic> fused;
  final List<Map<String, dynamic>> templateInsights;
  final String insightProvider;
  final Map<String, dynamic> llmDiagnostics;
  final String title;
  final String? moodLabel;
  final List<AiInsight> aiInsights;

  bool get hasImageThumbnail {
    final path = Uri.tryParse(effectiveThumbnailUrl)?.path.toLowerCase() ?? '';
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp');
  }

  String get displayTitle {
    final trimmedTitle = title.trim();
    return trimmedTitle.isEmpty ? prompt : trimmedTitle;
  }

  String get effectiveThumbnailUrl {
    final savedThumbnail = thumbnailUrl.trim();
    if (savedThumbnail.isNotEmpty) return savedThumbnail;

    final source = videoUrl.trim();
    if (source.isEmpty || !source.contains('/video/upload/')) return '';
    final transformed = source.replaceFirst(
      '/video/upload/',
      '/video/upload/so_0,f_jpg/',
    );
    return transformed.replaceFirstMapped(
      RegExp(r'\.(mp4|mov|webm|m4v)(\?.*)?$', caseSensitive: false),
      (match) => '.jpg${match.group(2) ?? ''}',
    );
  }

  factory JournalEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return JournalEntry(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      prompt: data['prompt'] as String? ?? 'Daily reflection',
      recordedAt: _date(data['recordedAt']),
      durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
      cloudinaryPublicId: data['cloudinaryPublicId'] as String? ?? '',
      videoUrl: data['videoUrl'] as String? ?? '',
      thumbnailUrl: data['thumbnailUrl'] as String? ?? '',
      uploadStatus: data['uploadStatus'] as String? ?? 'saved',
      analysisStatus: data['analysisStatus'] as String? ?? 'not_started',
      analysisStep: data['analysisStep'] as String? ?? '',
      analysisVersion: data['analysisVersion'] as String? ?? '',
      analysisError: data['analysisError'] as String?,
      analysisStartedAt: _nullableDate(data['analysisStartedAt']),
      analysisCompletedAt: _nullableDate(data['analysisCompletedAt']),
      transcript: JournalTranscript.fromMap(_dynamicMap(data['transcript'])),
      facial: _dynamicMap(data['facial']),
      voice: _dynamicMap(data['voice']),
      nlp: _dynamicMap(data['nlp']),
      fused: _dynamicMap(data['fused']),
      templateInsights: _mapList(data['templateInsights']),
      insightProvider: data['insightProvider'] as String? ?? '',
      llmDiagnostics: _dynamicMap(data['llmDiagnostics']),
      title: data['title'] as String? ?? '',
      moodLabel: data['moodLabel'] as String?,
      aiInsights:
          (data['aiInsights'] as List<dynamic>?)
              ?.whereType<Map>()
              .map(
                (item) => AiInsight.fromMap(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'prompt': prompt,
      'recordedAt': Timestamp.fromDate(recordedAt),
      'durationSeconds': durationSeconds,
      'cloudinaryPublicId': cloudinaryPublicId,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'uploadStatus': uploadStatus,
      'analysisStatus': analysisStatus,
      'analysisStep': analysisStep,
      'analysisVersion': analysisVersion,
      'analysisError': analysisError,
      'analysisStartedAt': analysisStartedAt == null
          ? null
          : Timestamp.fromDate(analysisStartedAt!),
      'analysisCompletedAt': analysisCompletedAt == null
          ? null
          : Timestamp.fromDate(analysisCompletedAt!),
      'transcript': transcript.toMap(),
      'facial': facial,
      'voice': voice,
      'nlp': nlp,
      'fused': fused,
      'templateInsights': templateInsights,
      'insightProvider': insightProvider,
      'llmDiagnostics': llmDiagnostics,
      'title': title,
      'moodLabel': moodLabel,
      'aiInsights': aiInsights.map((e) => e.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static DateTime _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  static DateTime? _nullableDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static Map<String, dynamic> _dynamicMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! Iterable) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) => item.map(
            (key, nestedValue) => MapEntry(key.toString(), nestedValue),
          ),
        )
        .toList(growable: false);
  }
}

class JournalTranscript {
  const JournalTranscript({
    this.text = '',
    this.wordCount = 0,
    this.language,
    this.confidence = 0.0,
  });

  final String text;
  final int wordCount;
  final String? language;
  final double confidence;

  bool get isAvailable => text.trim().isNotEmpty;

  factory JournalTranscript.fromMap(Map<String, dynamic> map) {
    return JournalTranscript(
      text: map['text'] as String? ?? '',
      wordCount: (map['wordCount'] as num?)?.toInt() ?? 0,
      language: map['language'] as String?,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
    'text': text,
    'wordCount': wordCount,
    'language': language,
    'confidence': confidence,
  };
}

class AiInsight {
  const AiInsight({
    required this.title,
    required this.summary,
    required this.moodLabel,
    this.dayThemes = const [],
    this.suggestions = const [],
    this.reflectionQuestions = const [],
    this.evidence = const {},
    this.confidence = 0.0,
    this.safetyNote = "",
  });

  final String title;
  final String summary;
  final String moodLabel;
  final List<String> dayThemes;
  final List<String> suggestions;
  final List<String> reflectionQuestions;
  final Map<String, dynamic> evidence;
  final double confidence;
  final String safetyNote;

  factory AiInsight.fromMap(Map<String, dynamic> map) {
    return AiInsight(
      title: map['title'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      moodLabel: map['moodLabel'] as String? ?? '',
      dayThemes: _stringList(map['dayThemes']),
      suggestions: _stringList(map['suggestions']),
      reflectionQuestions: _stringList(map['reflectionQuestions']),
      evidence: _dynamicMap(map['evidence']),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      safetyNote: map['safetyNote'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'summary': summary,
      'moodLabel': moodLabel,
      'dayThemes': dayThemes,
      'suggestions': suggestions,
      'reflectionQuestions': reflectionQuestions,
      'evidence': evidence,
      'confidence': confidence,
      'safetyNote': safetyNote,
    };
  }

  static List<String> _stringList(Object? value) {
    if (value is! Iterable) return const [];
    return value
        .whereType<Object>()
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static Map<String, dynamic> _dynamicMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
}
