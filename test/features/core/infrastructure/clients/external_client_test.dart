import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/external_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const sharedPreferencesChannel = MethodChannel(
    'plugins.flutter.io/shared_preferences',
  );

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sharedPreferencesChannel, (call) async {
          if (call.method == 'getAll') return <String, Object?>{};
          return null;
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sharedPreferencesChannel, null);
  });

  test('requires the Supabase configuration', () {
    expect(
      () => ExternalClient.ensureInitialized(url: '', publishableKey: ''),
      throwsA(isA<StateError>()),
    );
  });

  test('initializes Supabase and exposes authentication state', () async {
    final client = await ExternalClient.ensureInitialized(
      url: 'https://test.supabase.co',
      publishableKey: 'test-publishable-key',
    );

    expect(client.hasSession, isFalse);
    expect(client.events, isA<Stream<void>>());
  });
}
