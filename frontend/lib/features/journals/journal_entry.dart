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
  final String title;
  final String? moodLabel;
  final List<AiInsight> aiInsights;

  bool get hasImageThumbnail {
    final path = Uri.tryParse(thumbnailUrl)?.path.toLowerCase() ?? '';
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp');
  }

  String get displayTitle {
    final trimmedTitle = title.trim();
    return trimmedTitle.isEmpty ? prompt : trimmedTitle;
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
      title: data['title'] as String? ?? '',
      moodLabel: data['moodLabel'] as String?,
      aiInsights:
          (data['aiInsights'] as List<dynamic>?)
              ?.map((e) => AiInsight.fromMap(e as Map<String, dynamic>))
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
}

class AiInsight {
  const AiInsight({
    required this.title,
    required this.summary,
    required this.moodLabel,
    this.dayThemes = const [],
    this.suggestions = const [],
    this.reflectionQuestions = const [],
    this.confidence = 0.0,
    this.safetyNote = "",
  });

  final String title;
  final String summary;
  final String moodLabel;
  final List<String> dayThemes;
  final List<String> suggestions;
  final List<String> reflectionQuestions;
  final double confidence;
  final String safetyNote;

  factory AiInsight.fromMap(Map<String, dynamic> map) {
    return AiInsight(
      title: map['title'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      moodLabel: map['moodLabel'] as String? ?? '',
      dayThemes:
          (map['dayThemes'] as List<dynamic>?)?.cast<String>() ?? const [],
      suggestions:
          (map['suggestions'] as List<dynamic>?)?.cast<String>() ?? const [],
      reflectionQuestions:
          (map['reflectionQuestions'] as List<dynamic>?)?.cast<String>() ??
          const [],
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
      'confidence': confidence,
      'safetyNote': safetyNote,
    };
  }
}
