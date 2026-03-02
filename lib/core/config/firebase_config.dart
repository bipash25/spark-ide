import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase configuration for Spark IDE.
///
/// To set up Firebase for your project:
/// 1. Go to https://console.firebase.google.com
/// 2. Create a new project (or use an existing one)
/// 3. Add apps for each platform (Android, iOS, Web, etc.)
/// 4. Copy the config values below from the Firebase console
/// 5. Enable Authentication providers (Email/Password, Google, GitHub)
/// 6. Create a Firestore database in production mode
///
/// For GitHub OAuth:
/// 1. Go to GitHub Settings > Developer settings > OAuth Apps
/// 2. Create a new OAuth App with callback URL from Firebase console
/// 3. Copy Client ID and Secret into Firebase > Authentication > GitHub
class FirebaseConfig {
  /// Whether Firebase has been configured with real credentials.
  /// Set this to true after filling in the config values below.
  static const bool isConfigured = false;

  /// Firebase options for the current platform.
  /// Replace these placeholder values with your actual Firebase config.
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return web; // Desktop uses web config
      default:
        throw UnsupportedError(
          'FirebaseConfig is not supported for this platform.',
        );
    }
  }

  // ===== REPLACE THESE WITH YOUR FIREBASE CONFIG =====

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
    iosBundleId: 'com.sparkide.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
    iosBundleId: 'com.sparkide.app',
  );
}
