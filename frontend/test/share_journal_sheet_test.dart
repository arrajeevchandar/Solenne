import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solenne_frontend/features/auth/auth_providers.dart';
import 'package:solenne_frontend/features/journals/journal_entry.dart';
import 'package:solenne_frontend/features/social/social_models.dart';
import 'package:solenne_frontend/features/social/social_repository.dart';
import 'package:solenne_frontend/screens/friends/share_journal_sheet.dart';
import 'package:solenne_frontend/theme/app_theme.dart';

void main() {
  testWidgets('share sheet scrolls instead of overflowing with many friends', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(320, 568);
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    const owner = PublicProfile(
      uid: 'owner',
      displayName: 'Owner',
      username: 'owner_name',
      photoUrl: '',
    );
    final friendships = List.generate(12, (index) {
      final friend = PublicProfile(
        uid: 'friend-$index',
        displayName: 'Friend with a long name $index',
        username: 'friend_username_$index',
        photoUrl: '',
      );
      return Friendship(
        id: 'friend-$index-owner',
        requesterId: 'owner',
        recipientId: friend.uid,
        memberIds: [friend.uid, 'owner'],
        status: 'accepted',
        profiles: {'owner': owner, friend.uid: friend},
      );
    });
    final entry = JournalEntry(
      id: 'journal-1',
      userId: 'owner',
      prompt: 'Daily reflection',
      recordedAt: DateTime(2026, 8, 21),
      durationSeconds: 0,
      cloudinaryPublicId: '',
      videoUrl: '',
      thumbnailUrl: '',
      uploadStatus: 'saved',
      analysisStatus: 'complete',
      entryType: 'written',
      writtenText: 'A completed reflection.',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(
            MockFirebaseAuth(mockUser: MockUser(uid: 'owner'), signedIn: true),
          ),
          friendshipsProvider.overrideWith((ref) => friendships),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showShareJournalSheet(context, entry: entry),
                  child: const Text('Open sharing'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open sharing'));
    await tester.pumpAndSettle();

    expect(find.text('Share this journal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
