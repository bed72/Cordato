import 'package:firebase_core/firebase_core.dart';

import 'package:cordato/features/core/infrastructure/clients/firebase/firebase_options.dart';

abstract interface class IFirebaseClient {
  Future<void> initialize();
}

final class FirebaseClient implements IFirebaseClient {
  @override
  Future<void> initialize() async {
    await Firebase.initializeApp(
      name: 'Trocado',
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
