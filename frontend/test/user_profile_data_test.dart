import 'package:flutter_test/flutter_test.dart';
import 'package:solenne_frontend/features/auth/auth_providers.dart';

void main() {
  test('Firestore profile updates override cached Firebase profile values', () {
    final profile = UserProfileData.resolve(
      uid: 'user-1',
      authEmail: 'auth@example.com',
      authDisplayName: 'Old name',
      authPhotoUrl: 'https://example.com/old.jpg',
      document: const {
        'email': 'profile@example.com',
        'displayName': 'Updated name',
        'photoUrl': 'https://example.com/updated.jpg',
      },
    );

    expect(profile.email, 'profile@example.com');
    expect(profile.displayName, 'Updated name');
    expect(profile.photoUrl, 'https://example.com/updated.jpg');
  });

  test(
    'Firebase profile remains the fallback before Firestore data arrives',
    () {
      final profile = UserProfileData.resolve(
        uid: 'user-1',
        authEmail: 'auth@example.com',
        authDisplayName: 'Firebase name',
        authPhotoUrl: 'https://example.com/firebase.jpg',
      );

      expect(profile.email, 'auth@example.com');
      expect(profile.displayName, 'Firebase name');
      expect(profile.photoUrl, 'https://example.com/firebase.jpg');
    },
  );
}
