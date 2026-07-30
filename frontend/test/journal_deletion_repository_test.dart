import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solenne_frontend/features/journals/journal_entry.dart';
import 'package:solenne_frontend/features/journals/journal_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late JournalRepository repository;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(mockUser: MockUser(uid: 'user-1'), signedIn: true);
    repository = JournalRepository(firestore: firestore, auth: auth);
    await _saveJournal(firestore);
  });

  test('creates one deterministic queued deletion job', () async {
    await repository.deleteJournal('journal-1');
    await repository.deleteJournal('journal-1');

    final jobs = await firestore.collection('deletion_jobs').get();
    final job = jobs.docs.single;

    expect(job.id, 'journal-1');
    expect(job.data()['userId'], 'user-1');
    expect(job.data()['journalId'], 'journal-1');
    expect(job.data()['status'], 'queued');
    expect(job.data()['retryCount'], 0);
  });

  test('keeps journals visible for every pending deletion status', () async {
    for (final status in const ['queued', 'waiting', 'processing']) {
      await firestore.collection('deletion_jobs').doc('journal-1').set({
        'userId': 'user-1',
        'journalId': 'journal-1',
        'status': status,
      });

      final journals = await repository.watchJournals().first;
      final journal = await repository.watchJournal('journal-1').first;

      expect(journals.map((entry) => entry.id), contains('journal-1'));
      expect(journal?.id, 'journal-1');
    }
  });

  test(
    'journal disappears only after its Firestore document is deleted',
    () async {
      await repository.deleteJournal('journal-1');

      expect(
        (await repository.watchJournals().first).map((entry) => entry.id),
        contains('journal-1'),
      );

      await firestore
          .collection('users')
          .doc('user-1')
          .collection('journals')
          .doc('journal-1')
          .delete();

      expect(await repository.watchJournals().first, isEmpty);
      expect(await repository.watchJournal('journal-1').first, isNull);
    },
  );

  test('requeues a failed deterministic deletion job', () async {
    final job = firestore.collection('deletion_jobs').doc('journal-1');
    await job.set({
      'userId': 'user-1',
      'journalId': 'journal-1',
      'status': 'failed',
      'retryCount': 1,
      'errorCode': 'media_delete_failed',
      'errorMessage': 'Cloudinary unavailable',
    });

    await repository.deleteJournal('journal-1');

    final data = (await job.get()).data()!;
    expect(data['status'], 'queued');
    expect(data['errorCode'], isNull);
    expect(data['errorMessage'], isNull);
    expect(data['requestedAt'], isA<Timestamp>());
  });
}

Future<void> _saveJournal(FakeFirebaseFirestore firestore) {
  final entry = JournalEntry(
    id: 'journal-1',
    userId: 'user-1',
    prompt: 'Daily reflection',
    recordedAt: DateTime(2026, 7, 30),
    durationSeconds: 30,
    cloudinaryPublicId: 'solenne/journals/journal-1',
    videoUrl:
        'https://res.cloudinary.com/dqjd3lszl/video/upload/solenne/journals/journal-1.mp4',
    thumbnailUrl: '',
    uploadStatus: 'saved',
    analysisStatus: 'complete',
  );
  return firestore
      .collection('users')
      .doc('user-1')
      .collection('journals')
      .doc(entry.id)
      .set(entry.toFirestore());
}
