import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    required this.photoUrl,
  });

  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;

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
      photoUrl: _firstNonEmpty(document['photoUrl'], authPhotoUrl),
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
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(name);
    await ensureUserDocument(nameOverride: name);
    return credential;
  }

  Future<void> sendPasswordReset(String email) {
    return auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() => auth.signOut();

  Future<void> ensureUserDocument({String? nameOverride}) async {
    final user = auth.currentUser;
    if (user == null) return;
    final ref = firestore.collection('users').doc(user.uid);
    final snapshot = await ref.get();
    if (snapshot.exists) return;
    await ref.set({
      'email': user.email,
      'displayName': nameOverride ?? user.displayName ?? 'Friend',
      'onboardingComplete': false,
      'streakCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

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
