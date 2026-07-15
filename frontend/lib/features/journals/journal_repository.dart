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
    return _collection(user.uid).doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return JournalEntry.fromFirestore(doc);
    });
  }

  Future<void> saveJournal(JournalEntry entry) async {
    await _collection(entry.userId).doc(entry.id).set(entry.toFirestore());
    await firestore.collection('users').doc(entry.userId).set({
      'lastJournalAt': Timestamp.fromDate(entry.recordedAt),
      'streakCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
