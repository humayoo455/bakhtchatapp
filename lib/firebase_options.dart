import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

/// Firebase configuration supplied by each developer at build time.
class DefaultFirebaseOptions {
  static const String _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String _androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const String _iosAppId = String.fromEnvironment(
    'FIREBASE_IOS_APP_ID',
  );
  static const String _messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const String _iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'com.example.bakht',
  );

  static FirebaseOptions get currentPlatform {
    if (_apiKey.isEmpty ||
        _messagingSenderId.isEmpty ||
        _projectId.isEmpty ||
        _storageBucket.isEmpty) {
      throw StateError(
        'Firebase is not configured. Copy firebase_options.example.json to '
        'firebase_options.local.json, add your own Firebase values, and run '
        'with --dart-define-from-file=firebase_options.local.json.',
      );
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      if (_androidAppId.isEmpty) {
        throw StateError('FIREBASE_ANDROID_APP_ID is required on Android.');
      }
      return FirebaseOptions(
        apiKey: _apiKey,
        appId: _androidAppId,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        storageBucket: _storageBucket,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (_iosAppId.isEmpty) {
        throw StateError('FIREBASE_IOS_APP_ID is required on iOS.');
      }
      return FirebaseOptions(
        apiKey: _apiKey,
        appId: _iosAppId,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        storageBucket: _storageBucket,
        iosBundleId: _iosBundleId,
      );
    }
    throw UnsupportedError(
      'Bakht is currently configured for Android and iOS.',
    );
  }
}
