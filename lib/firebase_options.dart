import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
    import 'package:flutter/foundation.dart'
show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
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
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCN-PBMV0OVisdsmxHs1AcplW6cGpSb8sU',
    appId: '1:938638699606:web:df99581c45b221bcd35ff7',
    messagingSenderId: '938638699606',
    projectId: 'advertising-screen-refresh',
    authDomain: 'advertising-screen-refresh.firebaseapp.com',
    storageBucket: 'advertising-screen-refresh.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAZrr9BqzTagG857AYxW2dQPSxuc8QNCLk',
    appId: '1:938638699606:android:90905b31a077d7cdd35ff7',
    messagingSenderId: '938638699606',
    projectId: 'advertising-screen-refresh',
    storageBucket: 'advertising-screen-refresh.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDw9fLCZDc0rR2d-5IBfmGXWE6VLJGpb0M',
    appId: '1:938638699606:ios:1f360fb5ca3e5385d35ff7',
    messagingSenderId: '938638699606',
    projectId: 'advertising-screen-refresh',
    storageBucket: 'advertising-screen-refresh.firebasestorage.app',
    iosBundleId: 'com.example.advertisingScreen',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDw9fLCZDc0rR2d-5IBfmGXWE6VLJGpb0M',
    appId: '1:938638699606:ios:1f360fb5ca3e5385d35ff7',
    messagingSenderId: '938638699606',
    projectId: 'advertising-screen-refresh',
    storageBucket: 'advertising-screen-refresh.firebasestorage.app',
    iosBundleId: 'com.example.advertisingScreen',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCN-PBMV0OVisdsmxHs1AcplW6cGpSb8sU',
    appId: '1:938638699606:web:31762f0142957f88d35ff7',
    messagingSenderId: '938638699606',
    projectId: 'advertising-screen-refresh',
    authDomain: 'advertising-screen-refresh.firebaseapp.com',
    storageBucket: 'advertising-screen-refresh.firebasestorage.app',
  );
}
