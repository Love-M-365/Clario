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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
      apiKey: "AIzaSyDXeQ-_zSx9eZhv6LJrOnWoZ86gPt7Nf4A",
      authDomain: "clario-f60b0.firebaseapp.com",
      projectId: "clario-f60b0",
      storageBucket: "clario-f60b0.appspot.com",
      messagingSenderId: "1045577266956",
      appId: "1:1045577266956:web:db333d7530a920e52c3b29",
      databaseURL: 'https://clario-f60b0-default-rtdb.firebaseio.com/',
      measurementId: "G-174FQVWFZG");

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBy8jY6Y_wexM_F4ACe0nunxC5b7m5Jpi0',
    appId: '1:1045577266956:android:2f1a7b069cdc40192c3b29',
    messagingSenderId: '1045577266956',
    projectId: 'clario-f60b0',
    databaseURL: 'https://clario-f60b0-default-rtdb.firebaseio.com/',
    storageBucket: 'clario-f60b0.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBhDF_PrWdWl__HXtPq9MRwM1ygW6tCzmg',
    appId: '1:1045577266956:ios:5dce69d82443577e2c3b29',
    messagingSenderId: '1045577266956',
    projectId: 'clario-f60b0',
    databaseURL: 'https://clario-f60b0-default-rtdb.firebaseio.com/',
    storageBucket: 'clario-f60b0.firebasestorage.app',
    iosBundleId: 'com.example.clario',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBhDF_PrWdWl__HXtPq9MRwM1ygW6tCzmg',
    appId: '1:1045577266956:ios:5dce69d82443577e2c3b29',
    messagingSenderId: '1045577266956',
    projectId: 'clario-f60b0',
    databaseURL: 'https://clario-f60b0-default-rtdb.firebaseio.com/',
    storageBucket: 'clario-f60b0.firebasestorage.app',
    iosBundleId: 'com.example.clario',
  );
}
