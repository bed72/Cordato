import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';

import 'package:cordato/features/core/infrastructure/clients/firebase/firebase_client.dart';
import 'package:cordato/features/core/infrastructure/clients/firebase/firebase_options.dart';

import '../../../../../support/core/fakes/firebase_platform_fake.dart';

void main() {
  test('awaits mobile initialization and propagates SDK failures', () async {
    final originalPlatform = FirebasePlatform.instance;
    addTearDown(() {
      FirebasePlatform.instance = originalPlatform;
      debugDefaultTargetPlatformOverride = null;
    });
    final firebasePlatform = FirebasePlatformFake(
      initialize: (_) => throw StateError('Initialization not configured'),
    );
    FirebasePlatform.instance = firebasePlatform;

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      debugDefaultTargetPlatformOverride = platform;
      final expectedOptions = platform == .android
          ? DefaultFirebaseOptions.android
          : DefaultFirebaseOptions.ios;
      final completion = Completer<FirebaseAppPlatform>();

      FirebaseOptions? receivedOptions;
      firebasePlatform.initialize = (options) {
        receivedOptions = options;
        return completion.future;
      };
      bool initialized = false;

      final initialization = FirebaseClient.initialize().then((_) {
        initialized = true;
      });
      await Future<void>.delayed(Duration.zero);

      expect(initialized, isFalse);
      expect(receivedOptions, expectedOptions);
      expect(firebasePlatform.initializedName, isNull);

      completion.complete(FirebaseAppPlatform('[DEFAULT]', expectedOptions));
      await initialization;

      expect(initialized, isTrue);
    }

    final failure = StateError('Firebase initialization failed');
    firebasePlatform.initialize = (_) => Future.error(failure);

    await expectLater(FirebaseClient.initialize(), throwsA(same(failure)));
  });
}
