import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solenne_frontend/features/journals/journal_entry.dart';
import 'package:solenne_frontend/features/journals/journal_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late JournalRepository repository;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    repository = JournalRepository(
      firestore: firestore,
      auth: MockFirebaseAuth(mockUser: MockUser(uid: 'user-1'), signedIn: true),
    );
    await firestore.collection('users').doc('user-1').set({
      'aiConsentGranted': true,
    });
  });

  test(
    'written save creates one journal and one queued analysis job',
    () async {
      final entry = _writtenEntry();
      await repository.saveJournal(entry);
      await repository.saveJournal(entry);

      final journals = await firestore
          .collection('users')
          .doc('user-1')
          .collection('journals')
          .get();
      final jobs = await firestore.collection('analysis_jobs').get();
      expect(journals.docs, hasLength(1));
      expect(jobs.docs, hasLength(1));
      expect(journals.docs.single.data()['entryType'], 'written');
      expect(journals.docs.single.data()['videoUrl'], '');
      expect(
        jobs.docs.single.data()['analysisVersion'],
        JournalRepository.analysisVersion,
      );
    },
  );

  test('withdrawn AI consent saves journal without analysis job', () async {
    await firestore.collection('users').doc('user-1').update({
      'aiConsentGranted': false,
    });

    await repository.saveJournal(_writtenEntry());
    final journals = await firestore
        .collection('users')
        .doc('user-1')
        .collection('journals')
        .get();
    expect(journals.docs, hasLength(1));
    expect(journals.docs.single.data()['analysisStatus'], 'not_requested');
    expect(journals.docs.single.data()['analysisStep'], 'consent_withdrawn');
    expect((await firestore.collection('analysis_jobs').get()).docs, isEmpty);
  });
}

JournalEntry _writtenEntry() => JournalEntry(
  id: 'written-1',
  userId: 'user-1',
  prompt: 'Daily reflection',
  recordedAt: DateTime(2026, 8, 12),
  durationSeconds: 0,
  cloudinaryPublicId: '',
  videoUrl: '',
  thumbnailUrl: '',
  uploadStatus: 'saved',
  analysisStatus: 'queued',
  analysisStep: 'queued',
  analysisVersion: JournalRepository.analysisVersion,
  entryType: 'written',
  writtenText: 'Today I made space for one difficult thought.',
  mediaMimeType: 'text/plain',
  analysisModalities: const ['text'],
);
