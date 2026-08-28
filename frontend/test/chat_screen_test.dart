import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solenne_frontend/features/auth/auth_providers.dart';
import 'package:solenne_frontend/features/chat/chat_models.dart';
import 'package:solenne_frontend/features/chat/chat_repository.dart';
import 'package:solenne_frontend/features/social/social_models.dart';
import 'package:solenne_frontend/features/social/social_repository.dart';
import 'package:solenne_frontend/screens/friends/chat_screen.dart';
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

  testWidgets('direct chat presents an empty conversation safely', (
    tester,
  ) async {
    final conversation = ChatConversation(
      id: friendship.id,
      memberIds: friendship.memberIds,
      profiles: friendship.profiles,
      lastMessagePreview: '',
      lastMessageAt: null,
      lastMessageSenderId: '',
      unreadCounts: {},
      lastReadAt: {},
      typing: {},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(
            MockFirebaseAuth(
              mockUser: MockUser(uid: owner.uid),
              signedIn: true,
            ),
          ),
          relationshipsProvider.overrideWith(
            (ref) => Stream.value(const [friendship]),
          ),
          chatConversationProvider(
            friendship.id,
          ).overrideWith((ref) => Stream.value(conversation)),
          chatMessagesProvider(
            friendship.id,
          ).overrideWith((ref) => Stream.value(const <ChatMessage>[])),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: ChatScreen(
            conversationId: friendship.id,
            friendship: friendship,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Friend'), findsOneWidget);
    expect(find.text('A quiet space to begin.'), findsOneWidget);
    expect(find.text('Write a message...'), findsOneWidget);
  });
}
