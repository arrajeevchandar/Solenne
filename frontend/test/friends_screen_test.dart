import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solenne_frontend/features/auth/auth_providers.dart';
import 'package:solenne_frontend/features/social/social_models.dart';
import 'package:solenne_frontend/features/social/social_repository.dart';
import 'package:solenne_frontend/screens/friends/friends_screen.dart';
import 'package:solenne_frontend/theme/app_theme.dart';

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

  Widget app({List<Friendship> friendships = const []}) {
    return ProviderScope(
      overrides: [
        firebaseAuthProvider.overrideWithValue(
          MockFirebaseAuth(
            mockUser: MockUser(uid: 'owner-123'),
            signedIn: true,
          ),
        ),
        relationshipsProvider.overrideWith((ref) => Stream.value(friendships)),
        receivedSharesProvider.overrideWith((ref) => Stream.value(const [])),
        outgoingSharesProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const FriendsScreen(embedded: true),
      ),
    );
  }

  testWidgets('shared journals inbox is visible and opens', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('SHARED WITH ME'), findsOneWidget);
    await tester.tap(find.text('SHARED WITH ME'));
    await tester.pumpAndSettle();

    expect(find.text('Shared with me'), findsOneWidget);
    expect(find.text('Nothing has been shared yet.'), findsOneWidget);
  });

  testWidgets('friend row explicitly opens shared journal activity', (
    tester,
  ) async {
    await tester.pumpWidget(app(friendships: const [friendship]));
    await tester.pumpAndSettle();

    expect(find.byTooltip('View shared journals'), findsOneWidget);
    await tester.tap(find.byTooltip('View shared journals'));
    await tester.pumpAndSettle();

    expect(find.text('Journals they chose to share'), findsOneWidget);
    expect(
      find.text('No journals have been shared with you yet.'),
      findsOneWidget,
    );
  });

  testWidgets('outgoing shared journals shelf is visible and opens', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('SHARED BY ME'), findsOneWidget);
    await tester.tap(find.text('SHARED BY ME'));
    await tester.pumpAndSettle();

    expect(find.text('Shared by me'), findsOneWidget);
    expect(find.text('Nothing is being shared.'), findsOneWidget);
  });
}
