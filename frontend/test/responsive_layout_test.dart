import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solenne_frontend/features/auth/auth_providers.dart';
import 'package:solenne_frontend/features/journals/journal_entry.dart';
import 'package:solenne_frontend/features/social/social_models.dart';
import 'package:solenne_frontend/features/social/social_repository.dart';
import 'package:solenne_frontend/screens/friends/sharing_settings_screen.dart';
import 'package:solenne_frontend/screens/auth/auth_screen.dart';
import 'package:solenne_frontend/screens/onboarding/intention_setting_screen.dart';
import 'package:solenne_frontend/screens/onboarding/voice_calibration_screen.dart';
import 'package:solenne_frontend/screens/onboarding/walkthrough_screen.dart';
import 'package:solenne_frontend/screens/onboarding/welcome_screen.dart';
import 'package:solenne_frontend/screens/recording/audio_journal_screen.dart';
import 'package:solenne_frontend/screens/recording/journal_entry_picker_screen.dart';
import 'package:solenne_frontend/screens/recording/written_journal_screen.dart';
import 'package:solenne_frontend/screens/profile/profile_screen.dart';
import 'package:solenne_frontend/theme/app_theme.dart';

void main() {
  Future<void> pumpResponsive(
    WidgetTester tester,
    Widget screen,
    Size size, {
    List<SharedJournalEntry> outgoingShares = const [],
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(
            MockFirebaseAuth(
              mockUser: MockUser(
                uid: 'owner',
                email: 'owner@example.com',
                displayName: 'Owner with a long display name',
                photoURL: '',
              ),
              signedIn: true,
            ),
          ),
          userProfileProvider.overrideWith(
            (ref) => Stream.value(
              const UserProfileData(
                uid: 'owner',
                email: 'owner@example.com',
                displayName: 'Owner with a long display name',
                username: 'owner_with_a_long_username',
                photoUrl: '',
                aiConsentGranted: true,
                consentSource: 'accepted',
              ),
            ),
          ),
          outgoingSharesProvider.overrideWith(
            (ref) => Stream.value(outgoingShares),
          ),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: screen),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester.takeException(),
      isNull,
      reason:
          '${screen.runtimeType} overflowed at ${size.width}x${size.height}',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  }

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  testWidgets('onboarding screens fit compact phones', (tester) async {
    const size = Size(320, 568);
    await pumpResponsive(tester, const WelcomeScreen(), size);
    await pumpResponsive(tester, const WalkthroughScreen(), size);
    await pumpResponsive(tester, const IntentionSettingScreen(), size);
    await pumpResponsive(tester, const VoiceCalibrationScreen(), size);
    await pumpResponsive(tester, const AuthScreen(), size);
  });

  testWidgets('journal creation screens fit compact phones', (tester) async {
    const size = Size(320, 568);
    await pumpResponsive(tester, const JournalEntryPickerScreen(), size);
    await pumpResponsive(tester, const WrittenJournalScreen(), size);
    await pumpResponsive(tester, const AudioJournalScreen(), size);
  });

  testWidgets('sharing shelf fits compact phones', (tester) async {
    await pumpResponsive(
      tester,
      const SharingSettingsScreen(),
      const Size(320, 568),
    );
  });

  testWidgets('profile fits compact phones with long identity values', (
    tester,
  ) async {
    await pumpResponsive(tester, const ProfileScreen(), const Size(320, 568));
  });

  testWidgets('long outgoing share content fits compact phones', (
    tester,
  ) async {
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
      writtenText: 'A reflection.',
      title: 'A very long reflection title that still needs to fit cleanly',
    );
    final share = SharedJournalEntry(
      shareId: 'share-1',
      owner: const PublicProfile(
        uid: 'owner',
        displayName: 'Owner',
        username: 'owner_name',
        photoUrl: '',
      ),
      recipientId: 'friend',
      recipient: const PublicProfile(
        uid: 'friend',
        displayName: 'Friend',
        username: 'friend_with_a_long_username',
        photoUrl: '',
      ),
      entry: entry,
      includeTranscript: false,
      sharedAt: DateTime(2026, 8, 21),
    );
    await pumpResponsive(
      tester,
      const SharingSettingsScreen(),
      const Size(320, 568),
      outgoingShares: [share],
    );
  });
}
