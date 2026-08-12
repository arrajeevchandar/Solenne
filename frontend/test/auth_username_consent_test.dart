import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solenne_frontend/features/auth/auth_providers.dart';

void main() {
  test('registration requires every legal confirmation', () async {
    final repository = AuthRepository(
      auth: MockFirebaseAuth(),
      firestore: FakeFirebaseFirestore(),
    );

    await expectLater(
      repository.signUp(
        displayName: 'Quiet Moon',
        username: 'quiet_moon',
        email: 'quiet@example.com',
        password: 'secure-password',
        acceptedTerms: true,
        acceptedPrivacy: true,
        acceptedAiConsent: false,
      ),
      throwsStateError,
    );
  });

  test('username changes move the unique reservation', () async {
    final firestore = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(
      mockUser: MockUser(uid: 'user-123', displayName: 'Old Name'),
      signedIn: true,
    );
    await firestore.collection('users').doc('user-123').set({
      'displayName': 'Old Name',
      'username': 'old_name',
      'usernameNormalized': 'old_name',
      'photoUrl': 'https://example.com/photo.jpg',
    });
    await firestore.collection('usernames').doc('old_name').set({
      'uid': 'user-123',
      'username': 'old_name',
      'usernameNormalized': 'old_name',
      'displayName': 'Old Name',
      'photoUrl': 'https://example.com/photo.jpg',
    });

    final repository = AuthRepository(auth: auth, firestore: firestore);
    await repository.updateProfileIdentity(
      displayName: 'New Name',
      username: '@new_name',
    );

    expect(
      (await firestore.collection('usernames').doc('old_name').get()).exists,
      isFalse,
    );
    final reservation =
        (await firestore.collection('usernames').doc('new_name').get()).data()!;
    expect(reservation['uid'], 'user-123');
    expect(reservation['photoUrl'], 'https://example.com/photo.jpg');
  });

  test('username collision is rejected by the final transaction', () async {
    final firestore = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(
      mockUser: MockUser(uid: 'user-123'),
      signedIn: true,
    );
    await firestore.collection('users').doc('user-123').set({
      'username': 'old_name',
      'usernameNormalized': 'old_name',
    });
    await firestore.collection('usernames').doc('taken_name').set({
      'uid': 'someone-else',
    });

    final repository = AuthRepository(auth: auth, firestore: firestore);
    await expectLater(
      repository.updateProfileIdentity(
        displayName: 'New Name',
        username: 'taken_name',
      ),
      throwsA(isA<UsernameException>()),
    );
  });
}
