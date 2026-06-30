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
    this.moodLabel,
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
  final String? moodLabel;

  factory JournalEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
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
      moodLabel: data['moodLabel'] as String?,
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
      'moodLabel': moodLabel,
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
