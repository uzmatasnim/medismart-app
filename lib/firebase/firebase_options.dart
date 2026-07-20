// lib/firebase/firebase_options.dart
// Firebase configuration for both Android and Web platforms

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS not configured yet');
      default:
        throw UnsupportedError(
            'DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  /// Web Firebase configuration
  /// NOTE: You need to add a Web App in your Firebase Console and
  /// replace the appId below with the Web App ID
  /// Steps:
  /// 1. Go to https://console.firebase.google.com/project/medismart-app-ba167
  /// 2. Click "Add App" → Web icon
  /// 3. Register app name "MediSmart Web"
  /// 4. Copy the appId from the config and replace below
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAwMpOvIhAgY4nEcfD-BxrEJ01n9jSGYOY',
    authDomain: 'medismart-app-ba167.firebaseapp.com',
    projectId: 'medismart-app-ba167',
    storageBucket: 'medismart-app-ba167.firebasestorage.app',
    messagingSenderId: '671467188008',
    appId: '1:671467188008:web:REPLACE_WITH_YOUR_WEB_APP_ID',
    // ↑ Replace this with your actual Web App ID from Firebase Console
  );

  /// Android Firebase configuration (from google-services.json)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAwMpOvIhAgY4nEcfD-BxrEJ01n9jSGYOY',
    appId: '1:671467188008:android:faadbb623090ee2b7b6a1d',
    messagingSenderId: '671467188008',
    projectId: 'medismart-app-ba167',
    storageBucket: 'medismart-app-ba167.firebasestorage.app',
  );
}
