import 'package:cloud_firestore/cloud_firestore.dart';

import '../journals/journal_entry.dart';

class PublicProfile {
  const PublicProfile({
    required this.uid,
    required this.displayName,
    required this.username,
    required this.photoUrl,
  });

  final String uid;
  final String displayName;
  final String username;
  final String photoUrl;

  factory PublicProfile.fromMap(Map<String, dynamic> data) => PublicProfile(
    uid: data['uid'] as String? ?? '',
    displayName: data['displayName'] as String? ?? 'Friend',
    username: data['username'] as String? ?? '',
    photoUrl: data['photoUrl'] as String? ?? '',
  );
}

class Friendship {
  const Friendship({
    required this.id,
    required this.requesterId,
    required this.recipientId,
    required this.memberIds,
    required this.status,
    required this.profiles,
  });

  final String id;
  final String requesterId;
  final String recipientId;
  final List<String> memberIds;
  final String status;
  final Map<String, PublicProfile> profiles;

  factory Friendship.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final rawProfiles = data['profiles'] as Map? ?? const {};
    return Friendship(
      id: document.id,
      requesterId: data['requesterId'] as String? ?? '',
      recipientId: data['recipientId'] as String? ?? '',
      memberIds: (data['memberIds'] as Iterable? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      status: data['status'] as String? ?? 'pending',
      profiles: rawProfiles.map(
        (key, value) => MapEntry(
          key.toString(),
          PublicProfile.fromMap(
            (value as Map).map((key, value) => MapEntry(key.toString(), value)),
          ),
        ),
      ),
    );
  }

  PublicProfile other(String uid) =>
      profiles.entries.firstWhere((entry) => entry.key != uid).value;
}

class SharedJournalEntry {
  const SharedJournalEntry({
    required this.shareId,
    required this.owner,
    required this.recipientId,
    required this.recipient,
    required this.entry,
    required this.includeTranscript,
    required this.sharedAt,
  });

  final String shareId;
  final PublicProfile owner;
  final String recipientId;
  final PublicProfile recipient;
  final JournalEntry entry;
  final bool includeTranscript;
  final DateTime sharedAt;

  factory SharedJournalEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final journal = (data['journal'] as Map? ?? const {}).map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final owner = (data['ownerProfile'] as Map? ?? const {}).map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final recipient = (data['recipientProfile'] as Map? ?? const {}).map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final timestamp = data['sharedAt'];
    return SharedJournalEntry(
      shareId: document.id,
      owner: PublicProfile.fromMap(owner),
      recipientId: data['recipientId'] as String? ?? '',
      recipient: PublicProfile.fromMap(recipient),
      entry: JournalEntry.fromMap(data['journalId'] as String? ?? '', journal),
      includeTranscript: data['includeTranscript'] as bool? ?? false,
      sharedAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
    );
  }
}
