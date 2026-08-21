import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../journals/journal_entry.dart';
import 'social_models.dart';

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

final relationshipsProvider = StreamProvider<List<Friendship>>((ref) {
  return ref.watch(socialRepositoryProvider).watchRelationships();
});

final friendshipsProvider = Provider<List<Friendship>>(
  (ref) =>
      ref
          .watch(relationshipsProvider)
          .value
          ?.where((friendship) => friendship.status == 'accepted')
          .toList(growable: false) ??
      const [],
);

final incomingFriendRequestsProvider = Provider<List<Friendship>>((ref) {
  final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (uid == null) return const [];
  return ref
          .watch(relationshipsProvider)
          .value
          ?.where(
            (friendship) =>
                friendship.status == 'pending' && friendship.recipientId == uid,
          )
          .toList(growable: false) ??
      const [];
});

final incomingFriendRequestCountProvider = Provider<int>((ref) {
  return ref.watch(incomingFriendRequestsProvider).length;
});

final receivedSharesProvider = StreamProvider<List<SharedJournalEntry>>((ref) {
  return ref.watch(socialRepositoryProvider).watchReceivedShares();
});

final outgoingSharesProvider = StreamProvider<List<SharedJournalEntry>>((ref) {
  return ref.watch(socialRepositoryProvider).watchOutgoingShares();
});

class SocialRepository {
  SocialRepository({required this.firestore, required this.auth});

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  String get _uid {
    final value = auth.currentUser?.uid;
    if (value == null) throw StateError('You must be signed in.');
    return value;
  }

  Future<List<PublicProfile>> searchProfiles(String query) async {
    final normalized = AuthRepository.normalizeUsername(query);
    if (normalized.length < 3) return const [];
    late final QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await firestore
          .collection('usernames')
          .orderBy('usernameNormalized')
          .startAt([normalized])
          .endAt(['$normalized\uf8ff'])
          .limit(20)
          .get();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const SocialSearchException(
          'Username search is unavailable because access was denied.',
        );
      }
      rethrow;
    }
    return snapshot.docs
        .map((document) => PublicProfile.fromMap(document.data()))
        .where((profile) => profile.uid.isNotEmpty && profile.uid != _uid)
        .toList(growable: false);
  }

  Stream<List<Friendship>> watchRelationships() => firestore
      .collection('friendships')
      .where('memberIds', arrayContains: _uid)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map(Friendship.fromFirestore).toList(growable: false),
      );

  Stream<List<SharedJournalEntry>> watchReceivedShares() => firestore
      .collection('journal_shares')
      .where('recipientId', isEqualTo: _uid)
      .where('status', isEqualTo: 'active')
      .orderBy('sharedAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(SharedJournalEntry.fromFirestore)
            .toList(growable: false),
      );

  Stream<List<SharedJournalEntry>> watchOutgoingShares() => firestore
      .collection('journal_shares')
      .where('ownerId', isEqualTo: _uid)
      .where('status', isEqualTo: 'active')
      .orderBy('sharedAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(SharedJournalEntry.fromFirestore)
            .toList(growable: false),
      );

  Future<void> sendRequest(PublicProfile recipient) async {
    final owner = await _currentPublicProfile();
    final id = friendshipId(owner.uid, recipient.uid);
    final ref = firestore.collection('friendships').doc(id);
    await firestore.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists &&
          {'pending', 'accepted'}.contains(existing.data()?['status'])) {
        return;
      }
      transaction.set(ref, {
        'requesterId': owner.uid,
        'recipientId': recipient.uid,
        'memberIds': [owner.uid, recipient.uid]..sort(),
        'status': 'pending',
        'profiles': {
          owner.uid: _profileMap(owner),
          recipient.uid: _profileMap(recipient),
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> respond(Friendship friendship, {required bool accept}) async {
    if (friendship.recipientId != _uid || friendship.status != 'pending') {
      throw StateError('This request cannot be changed.');
    }
    final ref = firestore.collection('friendships').doc(friendship.id);
    final targetStatus = accept ? 'accepted' : 'declined';
    await firestore.runTransaction((transaction) async {
      final current = await transaction.get(ref);
      final data = current.data();
      if (!current.exists || data == null || data['recipientId'] != _uid) {
        throw StateError('This request is no longer available.');
      }
      if (data['status'] == targetStatus) return;
      if (data['status'] != 'pending') {
        throw StateError('This request has already been resolved.');
      }
      transaction.update(ref, {
        'status': targetStatus,
        'respondedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> cancelRequest(Friendship friendship) async {
    if (friendship.requesterId != _uid || friendship.status != 'pending') {
      throw StateError('This request cannot be cancelled.');
    }
    await firestore.collection('friendships').doc(friendship.id).update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeFriend(Friendship friendship) async {
    if (!friendship.memberIds.contains(_uid)) {
      throw StateError('This friendship does not belong to you.');
    }
    final friendId = friendship.other(_uid).uid;
    final shares = await firestore
        .collection('journal_shares')
        .where('memberIds', arrayContains: _uid)
        .where('friendshipId', isEqualTo: friendship.id)
        .where('status', isEqualTo: 'active')
        .get();
    final batch = firestore.batch()
      ..update(firestore.collection('friendships').doc(friendship.id), {
        'status': 'removed',
        'removedBy': _uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    for (final share in shares.docs) {
      final data = share.data();
      if (data['memberIds'] is List &&
          (data['memberIds'] as List).contains(friendId)) {
        batch.delete(share.reference);
      }
    }
    await batch.commit();
  }

  Future<void> shareJournal({
    required JournalEntry entry,
    required Iterable<Friendship> friendships,
    required bool includeTranscript,
  }) async {
    if (entry.userId != _uid || entry.analysisStatus != 'complete') {
      throw StateError('Only your completed journals can be shared.');
    }
    final userSnapshot = await firestore.collection('users').doc(_uid).get();
    if (userSnapshot.data()?['aiConsentGranted'] == false) {
      throw StateError(
        'Restore Data & AI Consent in Profile before sharing insights.',
      );
    }
    final profile = await _currentPublicProfile();
    final batch = firestore.batch();
    for (final friendship in friendships) {
      if (friendship.status != 'accepted' ||
          !friendship.memberIds.contains(_uid)) {
        throw StateError('A selected friendship is no longer active.');
      }
      final recipient = friendship.other(_uid);
      final ref = firestore
          .collection('journal_shares')
          .doc('${_uid}_${entry.id}_${recipient.uid}');
      batch.set(ref, {
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
    }
    await batch.commit();
  }

  Future<void> revokeShare(String shareId) =>
      firestore.collection('journal_shares').doc(shareId).delete();

  Future<PublicProfile> _currentPublicProfile() async {
    final snapshot = await firestore.collection('users').doc(_uid).get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    return PublicProfile(
      uid: _uid,
      displayName: data['displayName'] as String? ?? 'Friend',
      username: data['username'] as String? ?? '',
      photoUrl: data['photoUrl'] as String? ?? '',
    );
  }

  static String friendshipId(String first, String second) {
    final members = [first, second]..sort();
    return '${members.first}_${members.last}';
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

class SocialSearchException implements Exception {
  const SocialSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}
