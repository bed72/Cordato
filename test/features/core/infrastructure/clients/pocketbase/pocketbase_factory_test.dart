import 'dart:async';
import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:cordato/features/core/infrastructure/clients/pocketbase/pocketbase_factory.dart';

import '../../../../../support/core/mocks/flutter_secure_storage_mock.dart';
import '../../../../../support/core/fakes/secure_storage_channel_fake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlutterSecureStorageMock storage;
  const key = '@cordato.pocketbase_auth';

  setUp(() {
    storage = FlutterSecureStorageMock();
    final channel = SecureStorageChannelFake(storage: storage);
    channel.install();
    addTearDown(channel.dispose);
    when(() => storage.read(key: key)).thenAnswer((_) async => null);
    when(
      () => storage.write(
        key: key,
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
  });

  group('configuration', () {
    for (final session in [
      (
        description: 'locally expired token',
        token: 'eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjF9.signature',
        authorization: null,
      ),
      (
        description: 'remotely invalidated token',
        token: 'eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjQxMDI0NDQ4MDB9.signature',
        authorization:
            'eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjQxMDI0NDQ4MDB9.signature',
      ),
    ]) {
      test('preserves ${session.description} on HTTP 401', () async {
        when(() => storage.read(key: key)).thenAnswer(
          (_) async => jsonEncode({
            'token': session.token,
            'model': {'id': 'user-id', 'collectionName': 'users'},
          }),
        );
        final client = await PocketBaseFactory.create(
          url: 'https://example.com',
        );
        addTearDown(client.close);
        final changes = <AuthStoreEvent>[];
        final subscription = client.authStore.onChange.listen(changes.add);
        addTearDown(subscription.cancel);

        await http.runWithClient(
          () async {
            await expectLater(
              client.collection('expenses').getList(),
              throwsA(
                isA<ClientException>().having(
                  (exception) => exception.statusCode,
                  'statusCode',
                  401,
                ),
              ),
            );
          },
          () => MockClient((request) async {
            expect(request.headers['Authorization'], session.authorization);
            expect(client.authStore.token, session.token);

            return http.Response('{}', 401);
          }),
        );

        expect(client.authStore.token, session.token);
        expect(client.authStore.record?.id, 'user-id');
        expect(changes, isEmpty);
        verifyNever(() => storage.delete(key: key));
      });
    }

    for (final url in [
      'https://example.com',
      'https://example.com/backend',
      'http://127.0.0.1:8090',
    ]) {
      test('configures the SDK with $url', () async {
        final client = await PocketBaseFactory.create(url: url);
        addTearDown(client.close);

        expect(client.baseURL, url);
        expect(client.lang, 'pt-BR');
        expect(client.authStore, isA<AsyncAuthStore>());
        expect(client.buildURL('/api/health').toString(), '$url/api/health');
      });
    }

    test('does not expose a client before secure storage is loaded', () async {
      final read = Completer<String?>();
      when(() => storage.read(key: key)).thenAnswer((_) => read.future);

      final creating = PocketBaseFactory.create(url: 'https://example.com');
      read.complete(
        jsonEncode({
          'token': 'stored-token',
          'model': {'id': 'user-id'},
        }),
      );
      final client = await creating;
      addTearDown(client.close);

      expect(client.authStore.token, 'stored-token');
      expect(client.authStore.record?.id, 'user-id');
    });

    test('propagates initialization failure', () async {
      final failure = PlatformException(code: 'storage_unavailable');
      when(() => storage.read(key: key)).thenThrow(failure);

      await expectLater(
        PocketBaseFactory.create(url: 'https://example.com'),
        throwsA(
          isA<PlatformException>().having(
            (exception) => exception.code,
            'code',
            failure.code,
          ),
        ),
      );
    });
  });

  test(
    'reads only the SDK session key without migrating legacy sessions',
    () async {
      final client = await PocketBaseFactory.create(url: 'https://example.com');
      addTearDown(client.close);

      expect(client.authStore.token, isEmpty);
      verify(() => storage.read(key: key)).called(1);
      verifyNoMoreInteractions(storage);
    },
  );

  test(
    'clears memory immediately and delegates secure deletion to the SDK',
    () async {
      final deleted = Completer<void>();
      when(() => storage.delete(key: key)).thenAnswer((_) async {
        deleted.complete();
      });
      final client = await PocketBaseFactory.create(url: 'https://example.com');
      addTearDown(client.close);
      client.authStore.save('stored-token', null);

      client.authStore.clear();

      expect(client.authStore.token, isEmpty);
      expect(client.authStore.record, isNull);

      await deleted.future;

      verify(() => storage.delete(key: key)).called(1);
    },
  );

  test('SDK authenticates before persistence completes and attaches the token to CRUD', () async {
    const sdkToken = 'eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjQxMDI0NDQ4MDB9.signature';

    final write = Completer<void>();
    final written = Completer<void>();
    final authorization = Completer<String?>();

    addTearDown(() {
      if (!write.isCompleted) {
        write.complete();
      }
    });

    http.Client transport() => MockClient((request) async {
      if (request.url.path == '/api/collections/users/auth-with-password') {
        return http.Response(
          jsonEncode({
            'token': sdkToken,
            'record': {'id': 'user-id', 'collectionName': 'users'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      authorization.complete(request.headers['Authorization']);
      return http.Response(
        jsonEncode({
          'page': 1,
          'items': [],
          'perPage': 30,
          'totalItems': 0,
          'totalPages': 0,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    when(
      () => storage.write(
        key: key,
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {
      await write.future;
      written.complete();
    });

    final client = await PocketBaseFactory.create(url: 'https://example.com');

    addTearDown(client.close);

    await http.runWithClient(() async {
      await client
          .collection('users')
          .authWithPassword('test@example.com', 'Password1');

      expect(written.isCompleted, isFalse);
      expect(client.authStore.token, sdkToken);

      await client.collection('expenses').getList();
    }, transport);
    write.complete();
    await written.future;

    expect(await authorization.future, sdkToken);
    expect(client.authStore.record?.id, 'user-id');

    final encoded =
        verify(
              () => storage.write(
                key: key,
                value: captureAny(named: 'value'),
              ),
            ).captured.single
            as String;

    final savedAuth = jsonDecode(encoded) as Map<String, dynamic>;

    expect(savedAuth['token'], sdkToken);
    expect((savedAuth['model'] as Map)['id'], 'user-id');
  });
}
