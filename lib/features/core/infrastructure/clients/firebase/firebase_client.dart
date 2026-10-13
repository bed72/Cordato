import 'package:firebase_core/firebase_core.dart';

import 'package:cordato/features/core/infrastructure/clients/firebase/firebase_options.dart';

final class FirebaseClient {
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
