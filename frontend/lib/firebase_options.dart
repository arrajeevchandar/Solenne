import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError('Solenne is configured for Android and iOS.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD3HnRCt2cGT-2QsAw3dtlszHygT3R2FIE',
    appId: '1:682422521838:android:1bf4f7cdb8a00ed1b708ff',
    messagingSenderId: '682422521838',
    projectId: 'solenne-9324d',
    storageBucket: 'solenne-9324d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_IOS_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_IOS_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    iosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD3HnRCt2cGT-2QsAw3dtlszHygT3R2FIE',
    appId: '1:682422521838:web:solenne-frontend',
    messagingSenderId: '682422521838',
    projectId: 'solenne-9324d',
    authDomain: 'solenne-9324d.firebaseapp.com',
    storageBucket: 'solenne-9324d.firebasestorage.app',
  );
}
