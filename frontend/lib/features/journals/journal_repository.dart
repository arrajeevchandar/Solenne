import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'journal_entry.dart';

final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

final journalStreamProvider = StreamProvider<List<JournalEntry>>((ref) {
  return ref.watch(journalRepositoryProvider).watchJournals();
});

final journalByIdStreamProvider = StreamProvider.family<JournalEntry?, String>((
  ref,
  entryId,
) {
  return ref.watch(journalRepositoryProvider).watchJournal(entryId);
});

final journalRangeStreamProvider =
    StreamProvider.family<List<JournalEntry>, JournalDateRange>((ref, range) {
      return ref
          .watch(journalRepositoryProvider)
          .watchJournalsInRange(range.start, range.end);
    });

class JournalDateRange {
  const JournalDateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  @override
  bool operator ==(Object other) {
    return other is JournalDateRange &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode => Object.hash(start, end);
}

class JournalRepository {
  static const analysisVersion = '2026-08-v9-gpt-oss-insights';

  JournalRepository({required this.firestore, required this.auth});

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return firestore.collection('users').doc(uid).collection('journals');
  }

  Stream<List<JournalEntry>> watchJournals({int limit = 200}) {
    final user = auth.currentUser;
    if (user == null) return const Stream.empty();
    return _collection(user.uid)
        .orderBy('recordedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(JournalEntry.fromFirestore).toList(),
        );
  }

  Stream<List<JournalEntry>> watchJournalsInRange(
    DateTime start,
    DateTime end,
  ) {
    final user = auth.currentUser;
    if (user == null) return const Stream.empty();
    return _collection(user.uid)
        .where('recordedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('recordedAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('recordedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(JournalEntry.fromFirestore).toList(),
        );
  }

  Future<JournalEntry?> getJournal(String id) async {
    final user = auth.currentUser;
    if (user == null) return null;
    final doc = await _collection(user.uid).doc(id).get();
    if (!doc.exists) return null;
    return JournalEntry.fromFirestore(doc);
  }

  Stream<JournalEntry?> watchJournal(String id) {
    final user = auth.currentUser;
    if (user == null) return Stream.value(null);
    return _collection(user.uid)
        .doc(id)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return <JournalEntry>[];
          return <JournalEntry>[JournalEntry.fromFirestore(doc)];
        })
        .map((entries) => entries.isEmpty ? null : entries.first);
  }

  Future<void> saveJournal(JournalEntry entry) async {
    final journalRef = _collection(entry.userId).doc(entry.id);
    final jobRef = firestore.collection('analysis_jobs').doc(entry.id);
    final userRef = firestore.collection('users').doc(entry.userId);
    await firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final aiConsentGranted =
          userSnapshot.data()?['aiConsentGranted'] as bool? ?? true;
      final existingJournal = await transaction.get(journalRef);
      if (existingJournal.exists) {
        return;
      }

      final journalData = entry.toFirestore();
      if (!aiConsentGranted) {
        journalData
          ..['analysisStatus'] = 'not_requested'
          ..['analysisStep'] = 'consent_withdrawn'
          ..['analysisError'] = null
          ..['analysisErrorCode'] = null;
      }
      transaction.set(journalRef, journalData);
      if (aiConsentGranted && entry.analysisStatus == 'queued') {
        transaction.set(jobRef, {
          'userId': entry.userId,
          'journalId': entry.id,
          'status': 'queued',
          'processingStep': 'queued',
          'retryCount': 0,
          'attemptCount': 0,
          'analysisVersion': analysisVersion,
          'createdAt': FieldValue.serverTimestamp(),
          'startedAt': null,
          'completedAt': null,
          'errorMessage': null,
        });
      }
      transaction.set(userRef, {
        'lastJournalAt': Timestamp.fromDate(entry.recordedAt),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Queues permanent backend deletion of the journal and its Cloudinary media.
  Future<void> deleteJournal(String id) async {
    final user = auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to delete a journal.');
    }
    final jobRef = firestore.collection('deletion_jobs').doc(id);
    await firestore.runTransaction((transaction) async {
      final existing = await transaction.get(jobRef);
      if (!existing.exists) {
        transaction.set(jobRef, {
          'userId': user.uid,
          'journalId': id,
          'status': 'queued',
          'retryCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'startedAt': null,
          'completedAt': null,
          'errorCode': null,
          'errorMessage': null,
        });
        return;
      }
      final data = existing.data() ?? const <String, dynamic>{};
      if (data['userId'] != user.uid || data['journalId'] != id) {
        throw StateError('This deletion request does not belong to you.');
      }
      if (data['status'] == 'failed') {
        transaction.update(jobRef, {
          'status': 'queued',
          'startedAt': null,
          'completedAt': null,
          'errorCode': null,
          'errorMessage': null,
          'requestedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> retryAnalysis(String id) async {
    final user = auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to retry analysis.');
    }
    final journalRef = _collection(user.uid).doc(id);
    final jobRef = firestore.collection('analysis_jobs').doc(id);
    await firestore.runTransaction((transaction) async {
      final journal = await transaction.get(journalRef);
      final job = await transaction.get(jobRef);
      if (!journal.exists || journal.data()?['userId'] != user.uid) {
        throw StateError('This journal is no longer available.');
      }
      if (!job.exists || job.data()?['status'] != 'failed') {
        throw StateError('This analysis is not ready to be retried.');
      }
      transaction.update(jobRef, {
        'status': 'queued',
        'processingStep': 'queued',
        'analysisVersion': analysisVersion,
        'startedAt': null,
        'completedAt': null,
        'errorMessage': null,
        'attemptCount': 0,
        'retryCount': 0,
        'requestedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(journalRef, {
        'analysisStatus': 'queued',
        'analysisStep': 'queued',
        'analysisVersion': analysisVersion,
        'analysisError': null,
        'analysisErrorCode': null,
        'analysisRequestedAt': FieldValue.serverTimestamp(),
        'aiInsights': <Map<String, dynamic>>[],
        'templateInsights': <Map<String, dynamic>>[],
        'insightProvider': '',
      });
    });
  }
}
