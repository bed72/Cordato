import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState, EmptyLocalStorage, GoTrueClient, Session;

import 'package:cordato/features/core/domain/entities/auth_session_state.dart';
import 'package:cordato/features/core/infrastructure/clients/external_client.dart';

class _GoTrueClientMock extends Mock implements GoTrueClient {}

class _SessionMock extends Mock implements Session {}

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
      () => ExternalClient.ensureInitialized(
        client: const EmptyLocalStorage(),
        url: '',
        publishableKey: '',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('initializes Supabase and exposes authentication state', () async {
    final client = await ExternalClient.ensureInitialized(
      client: const EmptyLocalStorage(),
      url: 'https://test.supabase.co',
      publishableKey: 'test-publishable-key',
    );

    expect(client.hasSession, isFalse);
    expect(client.state, isA<ValueListenable<AuthSessionStateEnum>>());
    await client.dispose();
  });

  test('maps auth changes to routing session states', () async {
    final auth = _GoTrueClientMock();
    final events = StreamController<AuthState>();
    when(() => auth.onAuthStateChange).thenAnswer((_) => events.stream);
    final client = ExternalClient.forClient(client: auth);

    expect(client.state.value, AuthSessionStateEnum.loading);

    events.add(const AuthState(AuthChangeEvent.initialSession, null));
    await _flushEvents();
    expect(client.state.value, AuthSessionStateEnum.unauthenticated);

    events.add(AuthState(AuthChangeEvent.signedIn, _SessionMock()));
    await _flushEvents();
    expect(client.state.value, AuthSessionStateEnum.authenticated);

    events.add(AuthState(AuthChangeEvent.tokenRefreshed, _SessionMock()));
    await _flushEvents();
    expect(client.state.value, AuthSessionStateEnum.authenticated);

    events.add(const AuthState(AuthChangeEvent.signedOut, null));
    await _flushEvents();
    expect(client.state.value, AuthSessionStateEnum.unauthenticated);

    await client.dispose();
    await events.close();
  });

  test(
    'uses a recoverable state for unexpected auth observation errors',
    () async {
      final auth = _GoTrueClientMock();
      final events = StreamController<AuthState>();
      when(() => auth.onAuthStateChange).thenAnswer((_) => events.stream);
      final client = ExternalClient.forClient(client: auth);

      events.addError(StateError('refresh failed'));
      await _flushEvents();

      expect(client.state.value, AuthSessionStateEnum.restorationFailure);

      await client.dispose();
      await events.close();
    },
  );

  test('ignores auth events after disposal', () async {
    final auth = _GoTrueClientMock();
    final events = StreamController<AuthState>();
    when(() => auth.onAuthStateChange).thenAnswer((_) => events.stream);
    final client = ExternalClient.forClient(client: auth);

    events.add(AuthState(AuthChangeEvent.signedIn, _SessionMock()));
    await _flushEvents();
    await client.dispose();

    events.add(const AuthState(AuthChangeEvent.signedOut, null));
    await _flushEvents();

    expect(client.state.value, AuthSessionStateEnum.authenticated);
    await events.close();
  });
}

Future<void> _flushEvents() => Future<void>.delayed(Duration.zero);
