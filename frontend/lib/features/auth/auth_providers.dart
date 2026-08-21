import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'legal_documents.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).userChanges();
});

@immutable
class UserProfileData {
  const UserProfileData({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.username,
    required this.photoUrl,
    required this.aiConsentGranted,
    required this.consentSource,
  });

  final String uid;
  final String email;
  final String displayName;
  final String username;
  final String photoUrl;
  final bool aiConsentGranted;
  final String consentSource;

  factory UserProfileData.resolve({
    required String uid,
    String? authEmail,
    String? authDisplayName,
    String? authPhotoUrl,
    Map<String, dynamic> document = const {},
  }) {
    return UserProfileData(
      uid: uid,
      email: _firstNonEmpty(document['email'], authEmail),
      displayName: _firstNonEmpty(
        document['displayName'],
        authDisplayName,
        fallback: 'Friend',
      ),
      username: _firstNonEmpty(document['username'], null),
      photoUrl: _firstNonEmpty(document['photoUrl'], authPhotoUrl),
      aiConsentGranted: document['aiConsentGranted'] as bool? ?? true,
      consentSource: document['consentSource'] as String? ?? '',
    );
  }
}

final userProfileProvider = StreamProvider<UserProfileData?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map(
        (snapshot) => UserProfileData.resolve(
          uid: user.uid,
          authEmail: user.email,
          authDisplayName: user.displayName,
          authPhotoUrl: user.photoURL,
          document: snapshot.data() ?? const {},
        ),
      );
});

String _firstNonEmpty(
  Object? primary,
  String? secondary, {
  String fallback = '',
}) {
  final first = primary is String ? primary.trim() : '';
  if (first.isNotEmpty) return first;
  final second = secondary?.trim() ?? '';
  return second.isNotEmpty ? second : fallback;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

class AuthRepository {
  AuthRepository({required this.auth, required this.firestore});

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  User? get currentUser => auth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signUp({
    required String displayName,
    required String username,
    required String email,
    required String password,
    required bool acceptedTerms,
    required bool acceptedPrivacy,
    required bool acceptedAiConsent,
  }) async {
    if (!acceptedTerms || !acceptedPrivacy || !acceptedAiConsent) {
      throw StateError('All required agreements must be accepted.');
    }
    final normalizedUsername = normalizeUsername(username);
    if (!isUsernameValid(normalizedUsername)) {
      throw UsernameException(
        'Use 3-20 lowercase letters, numbers, or underscores.',
      );
    }
    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    try {
      await credential.user?.updateDisplayName(displayName);
      await _createUserWithUsername(
        user: credential.user!,
        displayName: displayName,
        username: normalizedUsername,
        consentSource: 'registration',
      );
      return credential;
    } catch (_) {
      await credential.user?.delete();
      rethrow;
    }
  }

  Future<void> sendPasswordReset(String email) {
    return auth.sendPasswordResetEmail(email: email);
  }

  Future<bool> isUsernameAvailable(String username) async {
    final normalized = normalizeUsername(username);
    if (!isUsernameValid(normalized)) return false;
    final snapshot = await firestore
        .collection('usernames')
        .doc(normalized)
        .get();
    return !snapshot.exists || snapshot.data()?['uid'] == currentUser?.uid;
  }

  Future<void> signOut() => auth.signOut();

  Future<void> ensureUserDocument({String? nameOverride}) async {
    final user = auth.currentUser;
    if (user == null) return;
    final ref = firestore.collection('users').doc(user.uid);
    final snapshot = await ref.get();
    final existing = snapshot.data() ?? const <String, dynamic>{};
    final rawUsername =
        (existing['usernameNormalized'] as String? ??
                existing['username'] as String? ??
                '')
            .trim();
    final currentUsername = normalizeUsername(rawUsername);
    if (snapshot.exists &&
        rawUsername == currentUsername &&
        isUsernameValid(currentUsername)) {
      final reservation = await firestore
          .collection('usernames')
          .doc(currentUsername)
          .get();
      if (reservation.exists && reservation.data()?['uid'] == user.uid) return;
    }

    final displayName = nameOverride ?? user.displayName ?? 'Friend';
    var generated = currentUsername;
    if (!isUsernameValid(generated) || !await isUsernameAvailable(generated)) {
      generated = await _availableGeneratedUsername(displayName, user.uid);
    }
    await _createUserWithUsername(
      user: user,
      displayName: displayName,
      username: generated,
      consentSource: 'legacy_assumed',
      merge: snapshot.exists,
      oldUsernameDocumentId: rawUsername,
    );
  }

  Future<void> updateProfileIdentity({
    required String displayName,
    required String username,
    String? photoUrl,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    final normalized = normalizeUsername(username);
    if (!isUsernameValid(normalized)) {
      throw UsernameException(
        'Use 3-20 lowercase letters, numbers, or underscores.',
      );
    }

    final userRef = firestore.collection('users').doc(user.uid);
    final newUsernameRef = firestore.collection('usernames').doc(normalized);
    var resolvedPhotoUrl = photoUrl ?? '';
    await firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      resolvedPhotoUrl =
          photoUrl ??
          userSnapshot.data()?['photoUrl'] as String? ??
          user.photoURL ??
          '';
      final oldUsernameDocumentId =
          (userSnapshot.data()?['usernameNormalized'] as String? ??
                  userSnapshot.data()?['username'] as String? ??
                  '')
              .trim();
      final oldUsernameRef = oldUsernameDocumentId.isNotEmpty
          ? firestore.collection('usernames').doc(oldUsernameDocumentId)
          : null;
      final usernameSnapshot = await transaction.get(newUsernameRef);
      final oldUsernameSnapshot =
          oldUsernameRef != null && oldUsernameRef.path != newUsernameRef.path
          ? await transaction.get(oldUsernameRef)
          : null;
      if (usernameSnapshot.exists &&
          usernameSnapshot.data()?['uid'] != user.uid) {
        throw UsernameException('That username is already taken.');
      }

      transaction.set(newUsernameRef, {
        'uid': user.uid,
        'username': normalized,
        'usernameNormalized': normalized,
        'displayName': displayName,
        'photoUrl': resolvedPhotoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(userRef, {
        'displayName': displayName,
        'username': normalized,
        'usernameNormalized': normalized,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (oldUsernameSnapshot?.exists == true &&
          oldUsernameSnapshot?.data()?['uid'] == user.uid) {
        transaction.delete(oldUsernameRef!);
      }
    });
    await user.updateDisplayName(displayName);
    try {
      await _syncSocialIdentity(
        userId: user.uid,
        displayName: displayName,
        username: normalized,
        photoUrl: resolvedPhotoUrl,
      );
    } catch (error, stackTrace) {
      // The canonical profile and username reservation have already committed.
      // A denormalized social-profile refresh is repairable and must not make
      // the UI report that the identity update itself failed.
      debugPrint('Social identity refresh deferred: $error\n$stackTrace');
    }
  }

  Future<void> _syncSocialIdentity({
    required String userId,
    required String displayName,
    required String username,
    required String photoUrl,
  }) async {
    final profile = {
      'uid': userId,
      'displayName': displayName,
      'username': username,
      'photoUrl': photoUrl,
    };
    final friendshipSnapshot = await firestore
        .collection('friendships')
        .where('memberIds', arrayContains: userId)
        .get();
    final shareSnapshot = await firestore
        .collection('journal_shares')
        .where('memberIds', arrayContains: userId)
        .where('status', isEqualTo: 'active')
        .get();
    final batch = firestore.batch();
    for (final document in friendshipSnapshot.docs) {
      batch.update(document.reference, {
        'profiles.$userId': profile,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    for (final document in shareSnapshot.docs) {
      final data = document.data();
      final profileField = data['ownerId'] == userId
          ? 'ownerProfile'
          : 'recipientProfile';
      batch.update(document.reference, {
        profileField: profile,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> setAiConsent(bool granted) async {
    final user = auth.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    await firestore.collection('users').doc(user.uid).set({
      'aiConsentGranted': granted,
      'aiConsentVersion': LegalConfig.aiConsentVersion,
      granted ? 'aiConsentRestoredAt' : 'aiConsentWithdrawnAt':
          FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _createUserWithUsername({
    required User user,
    required String displayName,
    required String username,
    required String consentSource,
    bool merge = false,
    String oldUsernameDocumentId = '',
  }) async {
    final userRef = firestore.collection('users').doc(user.uid);
    final usernameRef = firestore.collection('usernames').doc(username);
    await firestore.runTransaction((transaction) async {
      final reserved = await transaction.get(usernameRef);
      final oldUsernameRef =
          oldUsernameDocumentId.isNotEmpty && oldUsernameDocumentId != username
          ? firestore.collection('usernames').doc(oldUsernameDocumentId)
          : null;
      final oldReservation = oldUsernameRef == null
          ? null
          : await transaction.get(oldUsernameRef);
      if (reserved.exists && reserved.data()?['uid'] != user.uid) {
        throw UsernameException('That username is already taken.');
      }
      final now = FieldValue.serverTimestamp();
      transaction.set(usernameRef, {
        'uid': user.uid,
        'username': username,
        'usernameNormalized': username,
        'displayName': displayName,
        'photoUrl': user.photoURL ?? '',
        'updatedAt': now,
      });
      transaction.set(userRef, {
        'email': user.email,
        'displayName': displayName,
        'username': username,
        'usernameNormalized': username,
        'aiConsentGranted': true,
        'consentSource': consentSource,
        'termsVersion': LegalConfig.termsVersion,
        'privacyVersion': LegalConfig.privacyVersion,
        'aiConsentVersion': LegalConfig.aiConsentVersion,
        if (!merge) ...{
          'onboardingComplete': false,
          'streakCount': 0,
          'createdAt': now,
        },
        if (consentSource == 'registration') ...{
          'termsAcceptedAt': now,
          'privacyAcceptedAt': now,
          'aiConsentAcceptedAt': now,
        } else
          'assumedAt': now,
        'updatedAt': now,
      }, SetOptions(merge: merge));
      if (oldReservation?.exists == true &&
          oldReservation?.data()?['uid'] == user.uid) {
        transaction.delete(oldUsernameRef!);
      }
    });
  }

  Future<String> _availableGeneratedUsername(
    String displayName,
    String uid,
  ) async {
    var base = normalizeUsername(displayName.replaceAll(' ', '_'));
    base = base.replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (base.length < 3) base = 'solenne';
    if (base.length > 12) base = base.substring(0, 12);
    for (var attempt = 0; attempt < 10; attempt++) {
      final suffix =
          '${uid.substring(0, 6).toLowerCase()}${attempt == 0 ? '' : attempt}';
      final maxBase = 20 - suffix.length - 1;
      final baseLength = base.length.clamp(0, maxBase);
      final candidate = '${base.substring(0, baseLength)}_$suffix';
      final snapshot = await firestore
          .collection('usernames')
          .doc(candidate)
          .get();
      if (!snapshot.exists || snapshot.data()?['uid'] == uid) return candidate;
    }
    throw UsernameException('Could not generate a unique username.');
  }

  static String normalizeUsername(String value) =>
      value.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '');

  static bool isUsernameValid(String value) =>
      RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(value);

  Future<void> completeOnboarding({required String wellnessGoal}) async {
    final user = auth.currentUser;
    if (user == null) return;
    await firestore.collection('users').doc(user.uid).set({
      'wellnessGoal': wellnessGoal,
      'onboardingComplete': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class UsernameException implements Exception {
  const UsernameException(this.message);
  final String message;
  @override
  String toString() => message;
}
