import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../auth/auth_providers.dart';
import '../journals/journal_entry.dart';
import 'archive_file_writer.dart';

enum ExportKind {
  audio,
  transcript,
  both;

  String get wireValue => name;

  String get label => switch (this) {
    ExportKind.audio => 'Audio',
    ExportKind.transcript => 'Transcripts',
    ExportKind.both => 'Both',
  };
}

class ArchiveExportPolicy {
  const ArchiveExportPolicy._();

  static const maxSessions = 50;

  static List<String> normalizeSelection(Iterable<String> journalIds) {
    return journalIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .take(maxSessions)
        .toList(growable: false);
  }

  static bool hasRequestedContent(JournalEntry entry, ExportKind kind) {
    final hasAudio = entry.videoUrl.trim().isNotEmpty;
    final hasTranscript = entry.transcript.isAvailable;
    return switch (kind) {
      ExportKind.audio => hasAudio,
      ExportKind.transcript => hasTranscript,
      ExportKind.both => hasAudio || hasTranscript,
    };
  }
}

class ExportJob {
  const ExportJob({
    required this.id,
    required this.exportKind,
    required this.status,
    required this.processingStep,
    required this.selectedCount,
    required this.completedItems,
    required this.includedCount,
    required this.skippedCount,
    required this.filename,
    required this.createdAt,
    this.expiresAt,
    this.errorMessage,
  });

  final String id;
  final ExportKind exportKind;
  final String status;
  final String processingStep;
  final int selectedCount;
  final int completedItems;
  final int includedCount;
  final int skippedCount;
  final String filename;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? errorMessage;

  bool get isActive => const {'queued', 'processing', 'ready'}.contains(status);

  bool get isReady =>
      status == 'ready' &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  factory ExportJob.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final artifact = data['artifact'] is Map
        ? Map<String, dynamic>.from(data['artifact'] as Map)
        : const <String, dynamic>{};
    final wireKind = data['exportKind'] as String? ?? 'audio';
    return ExportJob(
      id: document.id,
      exportKind: ExportKind.values.firstWhere(
        (value) => value.wireValue == wireKind,
        orElse: () => ExportKind.audio,
      ),
      status: data['status'] as String? ?? 'queued',
      processingStep: data['processingStep'] as String? ?? 'queued',
      selectedCount: (data['journalIds'] as List?)?.length ?? 0,
      completedItems: (data['completedItems'] as num?)?.toInt() ?? 0,
      includedCount: (data['includedCount'] as num?)?.toInt() ?? 0,
      skippedCount: (data['skippedCount'] as num?)?.toInt() ?? 0,
      filename: artifact['filename'] as String? ?? 'solenne-journal-export.zip',
      createdAt: _date(data['createdAt']) ?? DateTime.now(),
      expiresAt: _date(data['expiresAt']),
      errorMessage: data['errorMessage'] as String?,
    );
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

final archiveRepositoryProvider = Provider<ArchiveRepository>((ref) {
  return ArchiveRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
    client: http.Client(),
  );
});

final exportJobStreamProvider = StreamProvider.family<ExportJob?, String>((
  ref,
  jobId,
) {
  return ref.watch(archiveRepositoryProvider).watchExport(jobId);
});

class ArchiveRepository {
  ArchiveRepository({
    required this.firestore,
    required this.auth,
    required this.client,
  });

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final http.Client client;

  Future<String> createExport({
    required List<String> journalIds,
    required ExportKind exportKind,
  }) async {
    final user = auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to export your journal.');
    }
    final selected = ArchiveExportPolicy.normalizeSelection(journalIds);
    if (selected.isEmpty) {
      throw StateError('Select at least one session.');
    }
    final reference = firestore.collection('export_jobs').doc();
    await reference.set({
      'userId': user.uid,
      'journalIds': selected,
      'exportKind': exportKind.wireValue,
      'status': 'queued',
      'processingStep': 'queued',
      'retryCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'startedAt': null,
      'completedAt': null,
      'errorCode': null,
      'errorMessage': null,
      'completedItems': 0,
    });
    return reference.id;
  }

  Stream<ExportJob?> watchExport(String jobId) {
    final user = auth.currentUser;
    if (user == null) return Stream.value(null);
    return firestore.collection('export_jobs').doc(jobId).snapshots().map((
      document,
    ) {
      if (!document.exists) return null;
      final job = ExportJob.fromFirestore(document);
      return job;
    });
  }

  Future<ExportJob?> latestActiveExport() async {
    final user = auth.currentUser;
    if (user == null) return null;
    final snapshot = await firestore
        .collection('export_jobs')
        .where('userId', isEqualTo: user.uid)
        .get();
    final jobs =
        snapshot.docs
            .map(ExportJob.fromFirestore)
            .where((job) => job.isActive)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return jobs.firstOrNull;
  }

  Future<DownloadedArchive> downloadExport(ExportJob job) async {
    final user = auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to download your export.');
    }
    if (!AppConfig.hasExportApi) {
      throw StateError('Export downloads are not configured for this build.');
    }
    final token = await user.getIdToken();
    if (token == null || token.trim().isEmpty) {
      throw StateError('Your sign-in session could not be verified.');
    }
    final base = AppConfig.exportApiBaseUrl.trim().replaceFirst(
      RegExp(r'/$'),
      '',
    );
    final request = http.Request(
      'GET',
      Uri.parse('$base/v1/exports/${job.id}/download'),
    )..headers['Authorization'] = 'Bearer $token';
    final response = await client.send(request);
    if (response.statusCode != 200) {
      final message = await response.stream.bytesToString();
      throw StateError(_downloadError(response.statusCode, message));
    }
    final contentDisposition = response.headers['content-disposition'] ?? '';
    final filename =
        RegExp(
          r'filename="([^"]+)"',
        ).firstMatch(contentDisposition)?.group(1) ??
        job.filename;
    return writeArchiveFile(filename, response.stream);
  }

  static String _downloadError(int status, String body) {
    if (status == 410) {
      return 'This one-time export has already been used or has expired.';
    }
    if (status == 409) return 'This export is not ready yet.';
    if (status == 401 || status == 403) {
      return 'Your session could not be verified. Sign in and try again.';
    }
    return 'The export could not be downloaded. ${body.trim()}'.trim();
  }
}
