import 'package:cloud_firestore/cloud_firestore.dart';

import '../social/social_models.dart';

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.memberIds,
    required this.profiles,
    required this.lastMessagePreview,
    required this.lastMessageAt,
    required this.lastMessageSenderId,
    required this.unreadCounts,
    this.active = true,
    this.schemaVersion = 1,
    this.lastMessageId = '',
    this.deliveredThrough = const {},
    Map<String, DateTime?>? readThrough,
    Map<String, DateTime?>? lastReadAt,
    required this.typing,
  }) : readThrough = readThrough ?? lastReadAt ?? const {};

  final String id;
  final List<String> memberIds;
  final Map<String, PublicProfile> profiles;
  final String lastMessagePreview;
  final DateTime? lastMessageAt;
  final String lastMessageSenderId;
  final Map<String, int> unreadCounts;
  final bool active;
  final int schemaVersion;
  final String lastMessageId;
  final Map<String, DateTime?> deliveredThrough;
  final Map<String, DateTime?> readThrough;
  final Map<String, ChatTypingState> typing;

  factory ChatConversation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return ChatConversation.fromMap(document.id, data);
  }

  factory ChatConversation.fromMap(String id, Map<String, dynamic> data) {
    final profiles = (data['profiles'] as Map? ?? const {}).map(
      (key, value) => MapEntry(
        key.toString(),
        PublicProfile.fromMap(
          (value as Map? ?? const {}).map(
            (profileKey, profileValue) =>
                MapEntry(profileKey.toString(), profileValue),
          ),
        ),
      ),
    );
    final unread = (data['unreadCounts'] as Map? ?? const {}).map(
      (key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
    );
    final delivered = (data['deliveredThrough'] as Map? ?? const {}).map(
      (key, value) => MapEntry(key.toString(), _dateOrNull(value)),
    );
    final readSource = data['readThrough'] ?? data['lastReadAt'];
    final read = (readSource as Map? ?? const {}).map(
      (key, value) => MapEntry(key.toString(), _dateOrNull(value)),
    );
    final typing = (data['typing'] as Map? ?? const {}).map(
      (key, value) => MapEntry(
        key.toString(),
        ChatTypingState.fromMap(
          (value as Map? ?? const {}).map(
            (typingKey, typingValue) =>
                MapEntry(typingKey.toString(), typingValue),
          ),
        ),
      ),
    );
    return ChatConversation(
      id: id,
      memberIds: (data['memberIds'] as Iterable? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      profiles: profiles,
      lastMessagePreview: data['lastMessagePreview'] as String? ?? '',
      lastMessageAt: _dateOrNull(data['lastMessageAt']),
      lastMessageSenderId: data['lastMessageSenderId'] as String? ?? '',
      unreadCounts: unread,
      active: data['active'] as bool? ?? true,
      schemaVersion: (data['schemaVersion'] as num?)?.toInt() ?? 1,
      lastMessageId: data['lastMessageId'] as String? ?? '',
      deliveredThrough: delivered,
      readThrough: read,
      typing: typing,
    );
  }

  PublicProfile other(String uid) => profiles.entries
      .firstWhere(
        (entry) => entry.key != uid,
        orElse: () => const MapEntry(
          '',
          PublicProfile(
            uid: '',
            displayName: 'Friend',
            username: '',
            photoUrl: '',
          ),
        ),
      )
      .value;

  int unreadFor(String uid) => unreadCounts[uid] ?? 0;

  DateTime? deliveredFor(String uid) => deliveredThrough[uid];

  DateTime? readFor(String uid) => readThrough[uid];

  bool isTyping(String uid) {
    final state = typing.entries
        .where((entry) => entry.key != uid)
        .map((entry) => entry.value)
        .where((state) => state.isFresh)
        .firstOrNull;
    return state?.active ?? false;
  }
}

class ChatTypingState {
  const ChatTypingState({required this.active, required this.updatedAt});

  final bool active;
  final DateTime? updatedAt;

  factory ChatTypingState.fromMap(Map<String, dynamic> data) => ChatTypingState(
    active: data['active'] as bool? ?? false,
    updatedAt: _dateOrNull(data['updatedAt']),
  );

  bool get isFresh =>
      updatedAt != null && DateTime.now().difference(updatedAt!).inSeconds < 12;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.type,
    required this.body,
    required this.shareId,
    required this.createdAt,
    required this.deleted,
    required this.deletedAt,
  });

  final String id;
  final String senderId;
  final String type;
  final String body;
  final String shareId;
  final DateTime? createdAt;
  final bool deleted;
  final DateTime? deletedAt;

  factory ChatMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return ChatMessage(
      id: document.id,
      senderId: data['senderId'] as String? ?? '',
      type: data['type'] as String? ?? 'text',
      body: data['body'] as String? ?? '',
      shareId: data['shareId'] as String? ?? '',
      createdAt: _dateOrNull(data['createdAt']),
      deleted: data['deleted'] as bool? ?? false,
      deletedAt: _dateOrNull(data['deletedAt']),
    );
  }

  bool get isJournalShare => type == 'journal_share';
}

DateTime? _dateOrNull(Object? value) =>
    value is Timestamp ? value.toDate() : null;
