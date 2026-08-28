import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../journals/journal_entry.dart';
import '../social/social_models.dart';
import 'chat_models.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

final conversationsProvider = StreamProvider<List<ChatConversation>>((ref) {
  return ref.watch(chatRepositoryProvider).watchConversations();
});

final chatConversationProvider =
    StreamProvider.family<ChatConversation?, String>((ref, conversationId) {
      return ref
          .watch(chatRepositoryProvider)
          .watchConversation(conversationId);
    });

final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>((
  ref,
  conversationId,
) {
  return ref.watch(chatRepositoryProvider).watchMessages(conversationId);
});

final chatShareProvider = StreamProvider.family<SharedJournalEntry?, String>((
  ref,
  shareId,
) {
  return ref.watch(chatRepositoryProvider).watchShare(shareId);
});

class ChatRepository {
  ChatRepository({required this.firestore, required this.auth});

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  String get _uid {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw StateError('You must be signed in to chat.');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _conversations =>
      firestore.collection('conversations');

  Stream<List<ChatConversation>> watchConversations() => _conversations
      .where('memberIds', arrayContains: _uid)
      .where('active', isEqualTo: true)
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(ChatConversation.fromFirestore)
            .toList(growable: false),
      );

  Stream<ChatConversation?> watchConversation(String conversationId) =>
      _conversations
          .doc(conversationId)
          .snapshots()
          .map(
            (document) => document.exists
                ? ChatConversation.fromFirestore(document)
                : null,
          );

  Stream<List<ChatMessage>> watchMessages(String conversationId) =>
      _conversations
          .doc(conversationId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(ChatMessage.fromFirestore)
                .toList(growable: false)
                .reversed
                .toList(growable: false),
          );

  Future<List<ChatMessage>> fetchOlderMessages(
    String conversationId, {
    required DateTime before,
  }) async {
    final snapshot = await _conversations
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .startAfter([Timestamp.fromDate(before)])
        .limit(50)
        .get();
    return snapshot.docs
        .map(ChatMessage.fromFirestore)
        .toList(growable: false)
        .reversed
        .toList(growable: false);
  }

  Stream<SharedJournalEntry?> watchShare(String shareId) {
    if (shareId.isEmpty) return Stream.value(null);
    return firestore
        .collection('journal_shares')
        .doc(shareId)
        .snapshots()
        .map(
          (document) => document.exists
              ? SharedJournalEntry.fromFirestore(document)
              : null,
        );
  }

  Future<void> sendText({
    required Friendship friendship,
    required String text,
  }) async {
    final body = text.trim();
    if (body.isEmpty) return;
    if (body.length > 2000) {
      throw StateError('Messages can be up to 2,000 characters.');
    }
    await _send(
      friendship: friendship,
      type: 'text',
      body: body,
      shareId: '',
      preview: body.replaceAll(RegExp(r'\s+'), ' '),
    );
  }

  Future<void> sendJournalShare({
    required Friendship friendship,
    required JournalEntry entry,
    required bool includeTranscript,
  }) async {
    if (entry.userId != _uid || entry.analysisStatus != 'complete') {
      throw StateError('Only your completed journals can be shared in chat.');
    }
    _assertFriendship(friendship);
    final recipient = friendship.other(_uid);
    final profile = await _currentProfile();
    final shareId = '${_uid}_${entry.id}_${recipient.uid}';
    final shareRef = firestore.collection('journal_shares').doc(shareId);
    final conversationRef = _conversations.doc(friendship.id);
    final messageRef = conversationRef.collection('messages').doc();
    await firestore.runTransaction((transaction) async {
      final current = await transaction.get(conversationRef);
      transaction.set(shareRef, {
        'ownerId': _uid,
        'recipientId': recipient.uid,
        'journalId': entry.id,
        'friendshipId': friendship.id,
        'memberIds': [_uid, recipient.uid]..sort(),
        'status': 'active',
        'includeTranscript': includeTranscript,
        'ownerProfile': _profileMap(profile),
        'recipientProfile': _profileMap(recipient),
        'journal': _shareSafeJournal(entry, includeTranscript),
        'analysisVersion': entry.analysisVersion,
        'sharedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _writeConversation(
        transaction: transaction,
        ref: conversationRef,
        current: current,
        friendship: friendship,
        messageId: messageRef.id,
        preview: 'Shared a reflection',
        recipientId: recipient.uid,
        sender: profile,
      );
      transaction.set(
        messageRef,
        _messageData(type: 'journal_share', body: '', shareId: shareId),
      );
    });
  }

  Future<void> _send({
    required Friendship friendship,
    required String type,
    required String body,
    required String shareId,
    required String preview,
  }) async {
    _assertFriendship(friendship);
    final sender = await _currentProfile();
    final recipient = friendship.other(_uid);
    final conversationRef = _conversations.doc(friendship.id);
    final messageRef = conversationRef.collection('messages').doc();
    await firestore.runTransaction((transaction) async {
      final current = await transaction.get(conversationRef);
      _writeConversation(
        transaction: transaction,
        ref: conversationRef,
        current: current,
        friendship: friendship,
        messageId: messageRef.id,
        preview: preview,
        recipientId: recipient.uid,
        sender: sender,
      );
      transaction.set(
        messageRef,
        _messageData(type: type, body: body, shareId: shareId),
      );
    });
  }

  void _writeConversation({
    required Transaction transaction,
    required DocumentReference<Map<String, dynamic>> ref,
    required DocumentSnapshot<Map<String, dynamic>> current,
    required Friendship friendship,
    required String messageId,
    required String preview,
    required String recipientId,
    required PublicProfile sender,
  }) {
    final previewText = preview.length > 140
        ? '${preview.substring(0, 137)}...'
        : preview;
    if (!current.exists) {
      transaction.set(ref, {
        'memberIds': List<String>.of(friendship.memberIds)..sort(),
        'profiles': {
          sender.uid: _profileMap(sender),
          recipientId: _profileMap(friendship.other(_uid)),
        },
        'active': true,
        'schemaVersion': 1,
        'lastMessageId': messageId,
        'lastMessagePreview': previewText,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': _uid,
        'unreadCounts': {_uid: 0, recipientId: FieldValue.increment(1)},
        'deliveredThrough': {_uid: FieldValue.serverTimestamp()},
        'readThrough': {_uid: FieldValue.serverTimestamp()},
        'typing': {
          _uid: {'active': false, 'updatedAt': FieldValue.serverTimestamp()},
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }
    if (current.data()?['active'] == false) {
      throw StateError('This conversation is no longer active.');
    }
    transaction.update(ref, {
      'lastMessageId': messageId,
      'lastMessagePreview': previewText,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': _uid,
      'unreadCounts.$_uid': 0,
      'unreadCounts.$recipientId': FieldValue.increment(1),
      'deliveredThrough.$_uid': FieldValue.serverTimestamp(),
      'readThrough.$_uid': FieldValue.serverTimestamp(),
      'typing.$_uid': {
        'active': false,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Map<String, dynamic> _messageData({
    required String type,
    required String body,
    required String shareId,
  }) => {
    'senderId': _uid,
    'type': type,
    'body': body,
    'shareId': shareId,
    'createdAt': FieldValue.serverTimestamp(),
    'deleted': false,
    'deletedAt': null,
  };

  Future<void> acknowledgeInbound({
    required ChatConversation conversation,
    required ChatMessage latestInbound,
  }) async {
    if (latestInbound.senderId == _uid || latestInbound.createdAt == null) {
      return;
    }
    final seenAt = latestInbound.createdAt!;
    final currentRead = conversation.readFor(_uid);
    if (conversation.unreadFor(_uid) == 0 &&
        currentRead != null &&
        !currentRead.isBefore(seenAt)) {
      return;
    }
    await _conversations.doc(conversation.id).update({
      'unreadCounts.$_uid': 0,
      'deliveredThrough.$_uid': Timestamp.fromDate(seenAt),
      'readThrough.$_uid': Timestamp.fromDate(seenAt),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setTyping(String conversationId, bool active) =>
      _conversations.doc(conversationId).update({
        'typing.$_uid': {
          'active': active,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteForEveryone({
    required String conversationId,
    required ChatMessage message,
  }) async {
    if (message.senderId != _uid || message.deleted) return;
    final conversationRef = _conversations.doc(conversationId);
    final messageRef = conversationRef.collection('messages').doc(message.id);
    await firestore.runTransaction((transaction) async {
      final conversation = await transaction.get(conversationRef);
      final currentMessage = await transaction.get(messageRef);
      if (!currentMessage.exists || currentMessage.data()?['deleted'] == true) {
        return;
      }
      transaction.update(messageRef, {
        'body': '',
        'shareId': '',
        'deleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });
      if (conversation.data()?['lastMessageId'] == message.id) {
        transaction.update(conversationRef, {
          'lastMessagePreview': 'Message removed',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<PublicProfile> _currentProfile() async {
    final snapshot = await firestore.collection('users').doc(_uid).get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    return PublicProfile(
      uid: _uid,
      displayName: data['displayName'] as String? ?? 'Friend',
      username: data['username'] as String? ?? '',
      photoUrl: data['photoUrl'] as String? ?? '',
    );
  }

  void _assertFriendship(Friendship friendship) {
    if (friendship.status != 'accepted' ||
        !friendship.memberIds.contains(_uid)) {
      throw StateError('Only accepted friends can chat.');
    }
  }

  static Map<String, dynamic> _profileMap(PublicProfile profile) => {
    'uid': profile.uid,
    'displayName': profile.displayName,
    'username': profile.username,
    'photoUrl': profile.photoUrl,
  };

  static Map<String, dynamic> _shareSafeJournal(
    JournalEntry entry,
    bool includeTranscript,
  ) => {
    'id': entry.id,
    'userId': entry.userId,
    'entryType': entry.entryType,
    'title': entry.title,
    'prompt': entry.prompt,
    'recordedAt': Timestamp.fromDate(entry.recordedAt),
    'durationSeconds': entry.durationSeconds,
    'videoUrl': entry.videoUrl,
    'audioUrl': entry.audioUrl,
    'writtenText': entry.writtenText,
    'mediaMimeType': entry.mediaMimeType,
    'thumbnailUrl': entry.thumbnailUrl,
    'uploadStatus': entry.uploadStatus,
    'analysisStatus': entry.analysisStatus,
    'analysisStep': entry.analysisStep,
    'analysisVersion': entry.analysisVersion,
    'moodLabel': entry.moodLabel,
    'aiInsights': entry.aiInsights.map((item) => item.toMap()).toList(),
    'insightProvider': entry.insightProvider,
    if (includeTranscript) 'transcript': entry.transcript.toMap(),
  };
}
