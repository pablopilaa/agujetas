import 'package:firebase_core/firebase_core.dart';
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
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAaj0BRktHST7pREXHB13erSkdim-TRPpk',
    appId: '1:727741646431:web:6bf44ea39c2187f54ebdea',
    messagingSenderId: '727741646431',
    projectId: 'agujetas',
    authDomain: 'agujetas.firebaseapp.com',
    storageBucket: 'agujetas.firebasestorage.app',
    measurementId: 'G-GP4YLJNSEZ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD9rAo-VM5guwfoPdr02f06B8zHiZuoOBc',
    appId: '1:727741646431:android:8d2a957f152624014ebdea',
    messagingSenderId: '727741646431',
    projectId: 'agujetas',
    storageBucket: 'agujetas.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA433Qi74hQ57FZX39iXR7CmZ59_mYDFkc',
    appId: '1:727741646431:ios:3592163d441933fd4ebdea',
    messagingSenderId: '727741646431',
    projectId: 'agujetas',
    storageBucket: 'agujetas.firebasestorage.app',
    iosBundleId: 'com.pablopilaa.agujetas',
  );
}
