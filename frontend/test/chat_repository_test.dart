import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solenne_frontend/features/chat/chat_repository.dart';
import 'package:solenne_frontend/features/journals/journal_entry.dart';
import 'package:solenne_frontend/features/social/social_models.dart';

void main() {
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

  late FakeFirebaseFirestore firestore;
  late ChatRepository repository;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    repository = ChatRepository(
      firestore: firestore,
      auth: MockFirebaseAuth(
        mockUser: MockUser(uid: owner.uid),
        signedIn: true,
      ),
    );
    await firestore.collection('users').doc(owner.uid).set({
      'displayName': owner.displayName,
      'username': owner.username,
      'photoUrl': owner.photoUrl,
    });
  });

  test(
    'sending text creates one direct conversation and one message',
    () async {
      await repository.sendText(friendship: friendship, text: 'Hello friend');

      final conversation = await firestore
          .collection('conversations')
          .doc(friendship.id)
          .get();
      final messages = await firestore
          .collection('conversations')
          .doc(friendship.id)
          .collection('messages')
          .get();

      expect(
        conversation.data()!['memberIds'],
        containsAll(friendship.memberIds),
      );
      expect(conversation.data()!['lastMessagePreview'], 'Hello friend');
      expect(conversation.data()!['active'], isTrue);
      expect(conversation.data()!['schemaVersion'], 1);
      expect(conversation.data()!['lastMessageId'], isNotEmpty);
      expect(conversation.data()!['unreadCounts'][friend.uid], 1);
      expect(messages.docs, hasLength(1));
      expect(messages.docs.single.data()['senderId'], owner.uid);
      expect(messages.docs.single.data()['body'], 'Hello friend');
    },
  );

  test('later messages preserve conversation creation time', () async {
    await repository.sendText(friendship: friendship, text: 'First');
    final first = await firestore
        .collection('conversations')
        .doc(friendship.id)
        .get();
    final createdAt = first.data()!['createdAt'];

    await repository.sendText(friendship: friendship, text: 'Second');
    final second = await firestore
        .collection('conversations')
        .doc(friendship.id)
        .get();

    expect(second.data()!['createdAt'], createdAt);
    expect(second.data()!['unreadCounts'][friend.uid], 2);
  });

  test('sender can remove their message for both participants', () async {
    await repository.sendText(friendship: friendship, text: 'A private note');
    final message =
        (await firestore
                .collection('conversations')
                .doc(friendship.id)
                .collection('messages')
                .get())
            .docs
            .single;
    final parsed = (await repository.watchMessages(friendship.id).first).single;

    await repository.deleteForEveryone(
      conversationId: friendship.id,
      message: parsed,
    );

    final updated = await message.reference.get();
    expect(updated.data()!['deleted'], isTrue);
    expect(updated.data()!['body'], isEmpty);
    expect(updated.data()!['shareId'], isEmpty);
    final conversation = await firestore
        .collection('conversations')
        .doc(friendship.id)
        .get();
    expect(conversation.data()!['lastMessagePreview'], 'Message removed');
  });

  test(
    'chat journal share uses the existing recipient-safe projection',
    () async {
      final entry = JournalEntry(
        id: 'journal-1',
        userId: owner.uid,
        prompt: 'Daily reflection',
        recordedAt: DateTime(2026, 8, 25),
        durationSeconds: 18,
        cloudinaryPublicId: '',
        videoUrl: '',
        thumbnailUrl: '',
        uploadStatus: 'saved',
        analysisStatus: 'complete',
        facial: const {'confidence': 0.9},
        transcript: const JournalTranscript(text: 'Private transcript'),
        aiInsights: const [
          AiInsight(
            title: 'A steady moment',
            summary: 'A quiet reflection.',
            moodLabel: 'reflective',
          ),
        ],
      );

      await repository.sendJournalShare(
        friendship: friendship,
        entry: entry,
        includeTranscript: false,
      );

      final share = await firestore
          .collection('journal_shares')
          .doc('${owner.uid}_${entry.id}_${friend.uid}')
          .get();
      final messages = await firestore
          .collection('conversations')
          .doc(friendship.id)
          .collection('messages')
          .get();
      final projection = share.data()!['journal'] as Map<String, dynamic>;

      expect(share.data()!['recipientId'], friend.uid);
      expect(projection.containsKey('facial'), isFalse);
      expect(projection.containsKey('transcript'), isFalse);
      expect(messages.docs.single.data()['type'], 'journal_share');
      expect(messages.docs.single.data()['shareId'], share.id);
    },
  );
}
