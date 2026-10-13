import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case .android:
        return android;
      case .iOS:
        return ios;
      case .macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case .windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case .linux:
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

  static const android = FirebaseOptions(
    projectId: 'trocado-d362e',
    messagingSenderId: '929522866059',
    apiKey: 'AIzaSyDEdPizW8LfvxWDrvnU5dziY7Vm_Zc5rK0',
    storageBucket: 'trocado-d362e.firebasestorage.app',
    appId: '1:929522866059:android:7303f64f0cd02c16f7418e',
  );

  static const ios = FirebaseOptions(
    projectId: 'trocado-d362e',
    iosBundleId: 'com.bed.cordato',
    messagingSenderId: '929522866059',
    apiKey: 'AIzaSyB-nzGY1-y_UXhNPFIZgR_eHXMqhW_BrQM',
    appId: '1:929522866059:ios:8899d2655bbd64d9f7418e',
    storageBucket: 'trocado-d362e.firebasestorage.app',
  );
}
