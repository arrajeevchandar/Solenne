import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solenne_frontend/features/journals/journal_entry.dart';
import 'package:solenne_frontend/features/social/social_models.dart';
import 'package:solenne_frontend/features/social/social_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late SocialRepository repository;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    repository = SocialRepository(
      firestore: firestore,
      auth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'owner-123'),
        signedIn: true,
      ),
    );
    await firestore.collection('users').doc('owner-123').set({
      'displayName': 'Owner',
      'username': 'owner_name',
      'photoUrl': '',
      'aiConsentGranted': true,
    });
  });

  test('friend request moves from pending to accepted', () async {
    const recipient = PublicProfile(
      uid: 'friend-456',
      displayName: 'Friend',
      username: 'friend_name',
      photoUrl: '',
    );
    await repository.sendRequest(recipient);
    final id = SocialRepository.friendshipId('owner-123', 'friend-456');
    final data = (await firestore.collection('friendships').doc(id).get())
        .data()!;
    expect(data['status'], 'pending');
    expect(data['requesterId'], 'owner-123');
  });

  test('accepting the same request twice is idempotent', () async {
    const owner = PublicProfile(
      uid: 'friend-456',
      displayName: 'Friend',
      username: 'friend_name',
      photoUrl: '',
    );
    const recipient = PublicProfile(
      uid: 'owner-123',
      displayName: 'Owner',
      username: 'owner_name',
      photoUrl: '',
    );
    const friendship = Friendship(
      id: 'friend-456_owner-123',
      requesterId: 'friend-456',
      recipientId: 'owner-123',
      memberIds: ['friend-456', 'owner-123'],
      status: 'pending',
      profiles: {'friend-456': owner, 'owner-123': recipient},
    );
    await firestore.collection('friendships').doc(friendship.id).set({
      'requesterId': friendship.requesterId,
      'recipientId': friendship.recipientId,
      'memberIds': friendship.memberIds,
      'status': friendship.status,
      'profiles': {
        'friend-456': {
          'uid': owner.uid,
          'displayName': owner.displayName,
          'username': owner.username,
          'photoUrl': owner.photoUrl,
        },
        'owner-123': {
          'uid': recipient.uid,
          'displayName': recipient.displayName,
          'username': recipient.username,
          'photoUrl': recipient.photoUrl,
        },
      },
    });

    await repository.respond(friendship, accept: true);
    await repository.respond(friendship, accept: true);

    final data =
        (await firestore.collection('friendships').doc(friendship.id).get())
            .data()!;
    expect(data['status'], 'accepted');
  });

  test(
    'removing a friend revokes active shares and marks relationship removed',
    () async {
      const owner = PublicProfile(
        uid: 'owner-123',
        displayName: 'Owner',
        username: 'owner_name',
        photoUrl: '',
      );
      const friend = PublicProfile(
        uid: 'friend-456',
        displayName: 'Friend',
        username: 'friend_name',
        photoUrl: '',
      );
      const friendship = Friendship(
        id: 'friend-456_owner-123',
        requesterId: 'owner-123',
        recipientId: 'friend-456',
        memberIds: ['friend-456', 'owner-123'],
        status: 'accepted',
        profiles: {'owner-123': owner, 'friend-456': friend},
      );
      await firestore.collection('friendships').doc(friendship.id).set({
        'requesterId': friendship.requesterId,
        'recipientId': friendship.recipientId,
        'memberIds': friendship.memberIds,
        'status': friendship.status,
        'profiles': {
          'owner-123': {
            'uid': owner.uid,
            'displayName': owner.displayName,
            'username': owner.username,
            'photoUrl': owner.photoUrl,
          },
          'friend-456': {
            'uid': friend.uid,
            'displayName': friend.displayName,
            'username': friend.username,
            'photoUrl': friend.photoUrl,
          },
        },
      });
      await firestore.collection('journal_shares').doc('share-1').set({
        'memberIds': friendship.memberIds,
        'friendshipId': friendship.id,
        'status': 'active',
      });

      await repository.removeFriend(friendship);

      final relationship =
          (await firestore.collection('friendships').doc(friendship.id).get())
              .data()!;
      expect(relationship['status'], 'removed');
      expect(relationship['removedBy'], 'owner-123');
      expect(
        (await firestore.collection('journal_shares').doc('share-1').get())
            .exists,
        isFalse,
      );
    },
  );

  test(
    'share projection excludes raw metrics and transcript by default',
    () async {
      const friend = PublicProfile(
        uid: 'friend-456',
        displayName: 'Friend',
        username: 'friend_name',
        photoUrl: '',
      );
      const owner = PublicProfile(
        uid: 'owner-123',
        displayName: 'Owner',
        username: 'owner_name',
        photoUrl: '',
      );
      const friendship = Friendship(
        id: 'friend-456_owner-123',
        requesterId: 'owner-123',
        recipientId: 'friend-456',
        memberIds: ['friend-456', 'owner-123'],
        status: 'accepted',
        profiles: {'owner-123': owner, 'friend-456': friend},
      );
      final entry = JournalEntry(
        id: 'journal-1',
        userId: 'owner-123',
        prompt: 'Daily reflection',
        recordedAt: DateTime(2026, 8, 12),
        durationSeconds: 20,
        cloudinaryPublicId: 'solenne/journals/journal-1',
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: '',
        uploadStatus: 'saved',
        analysisStatus: 'complete',
        facial: const {'confidence': 0.9},
        transcript: const JournalTranscript(text: 'Private transcript'),
        aiInsights: const [
          AiInsight(
            title: 'A steady moment',
            summary: 'The reflection focused on making room for rest.',
            moodLabel: 'reflective',
          ),
        ],
      );

      await repository.shareJournal(
        entry: entry,
        friendships: const [friendship],
        includeTranscript: false,
      );

      final share = (await firestore.collection('journal_shares').get())
          .docs
          .single
          .data();
      final projection = share['journal'] as Map<String, dynamic>;
      expect(projection['aiInsights'], isNotEmpty);
      expect(projection.containsKey('transcript'), isFalse);
      expect(projection.containsKey('facial'), isFalse);
      expect(projection.containsKey('fused'), isFalse);
    },
  );

  test('revoking a share removes its projection', () async {
    await firestore.collection('journal_shares').doc('share-1').set({
      'ownerId': 'owner-123',
      'recipientId': 'friend-456',
      'status': 'active',
    });

    await repository.revokeShare('share-1');

    expect(
      (await firestore.collection('journal_shares').doc('share-1').get())
          .exists,
      isFalse,
    );
  });
}
