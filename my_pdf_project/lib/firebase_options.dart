// STUB — run `flutterfire configure` to replace this file with real values.
// Steps:
//   1. dart pub global activate flutterfire_cli
//   2. flutterfire configure --project=<your-firebase-project-id>
// That will regenerate this file with real API keys.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('DefaultFirebaseOptions not configured for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDTgPTsIIB67u_kZnYIWiKCBijD6Catisc',
    appId: '1:537882167636:android:1187bdfa1cebd97fd9a0c1',
    messagingSenderId: '537882167636',
    projectId: 'readtrack-8262c',
    storageBucket: 'readtrack-8262c.firebasestorage.app',
  );

  // Replace all values below after running `flutterfire configure`
}