import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.royalBlue,
    ),
  );
  runApp(const ProviderScope(child: SolenneBootstrap()));
}

class SolenneBootstrap extends StatefulWidget {
  const SolenneBootstrap({super.key});

  @override
  State<SolenneBootstrap> createState() => _SolenneBootstrapState();
}

class _SolenneBootstrapState extends State<SolenneBootstrap> {
  late final Future<void> _startup = _initializeFirebase();

  Future<void> _initializeFirebase() async {
    if (Firebase.apps.isNotEmpty) return;
    if (kIsWeb) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
      return;
    }
    await Firebase.initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _startup,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return SolenneApp(
            isAuthenticated: FirebaseAuth.instance.currentUser != null,
          );
        }
        if (snapshot.hasError) {
          return _StartupErrorApp(error: snapshot.error);
        }
        return const _StartupLoadingApp();
      },
    );
  }
}

class _StartupLoadingApp extends StatelessWidget {
  const _StartupLoadingApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const Scaffold(
        body: SolenneBackground(
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.quicksand,
              strokeWidth: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final Object? error;

  String get _firebaseSetupMessage {
    final platformMessage = kIsWeb
        ? 'the web options in lib/firebase_options.dart match project '
              'solenne-9324d and that a Firebase Web app is registered.'
        : 'android/app/google-services.json exists and matches the package '
              'com.spd.solenne.';
    return 'Firebase failed to initialize. Confirm that $platformMessage';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Scaffold(
        body: SolenneBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 46,
                    color: AppColors.quicksand.withValues(alpha: 0.9),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Solenne could not start',
                    style: AppTextStyles.display(fontSize: 34),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _firebaseSetupMessage,
                    style: AppTextStyles.body(fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    error.toString(),
                    style: AppTextStyles.mono(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
