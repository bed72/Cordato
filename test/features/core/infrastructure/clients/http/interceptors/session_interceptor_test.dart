import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/interceptors/session_interceptor.dart';

import '../../../../../../support/core/mocks/storage_client_mock.dart';

void main() {
  late StorageClientMock storage;
  late HttpClient client;
  late int responseStatus;
  late RequestOptions? captured;

  setUp(() {
    storage = StorageClientMock();
    captured = null;
    responseStatus = 200;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/'))
      ..interceptors.add(SessionInterceptor(storage: storage));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(
            Response<String>(
              requestOptions: options,
              statusCode: responseStatus,
              data: '{}',
            ),
            true,
          );
        },
      ),
    );
    client = HttpClient(dio: dio);
  });

  test('adds the stored bearer token only to protected requests', () async {
    when(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
        .thenAnswer((_) async => 'opaque-token');

    await client.get(parameter: const Requests(path: 'expenses'));

    expect(captured!.headers['Authorization'], 'Bearer opaque-token');
    verify(() => storage.read(key: StorageKeyEnum.opaqueToken.key)).called(1);

    await client.post(
      parameter: const Requests(path: 'authentication/sign-in'),
    );

    expect(captured!.headers.containsKey('Authorization'), isFalse);
    verifyNever(() => storage.read(key: StorageKeyEnum.opaqueToken.key));
  });

  test('does not send Authorization without a saved token', () async {
    when(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
        .thenAnswer((_) async => null);

    await client.get(parameter: const Requests(path: 'expenses'));

    expect(captured!.headers.containsKey('Authorization'), isFalse);
  });

  test('authenticates GET, PATCH and DELETE of the user resource', () async {
    when(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
        .thenAnswer((_) async => 'opaque-token');
    const parameter = Requests(path: 'users/10');

    await client.get(parameter: parameter);
    expect(captured!.uri.path, '/api/users/10');
    expect(captured!.headers['Authorization'], 'Bearer opaque-token');
    await client.patch(parameter: parameter);
    expect(captured!.headers['Authorization'], 'Bearer opaque-token');
    await client.delete(parameter: parameter);
    expect(captured!.headers['Authorization'], 'Bearer opaque-token');
  });

  test('does not authenticate unrelated or external user paths', () async {
    for (final path in [
      'users',
      'users/',
      'users/10/expenses',
      'https://example.com/users/10',
      'other/10',
      'https://external.example/api/users/10',
      'https://example.com/api/users/10',
      'users/10/../11/expenses',
    ]) {
      await client.get(parameter: Requests(path: path));
      expect(captured!.headers.containsKey('Authorization'), isFalse);
    }
    verifyNever(() => storage.read(key: StorageKeyEnum.opaqueToken.key));
  });

  test('removes the sent token after a user resource returns 401', () async {
    responseStatus = 401;
    when(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
        .thenAnswer((_) async => 'opaque-token');
    when(() => storage.delete(key: StorageKeyEnum.opaqueToken.key))
        .thenAnswer((_) async {});

    final response = await client.get(
      parameter: const Requests(path: 'users/10'),
    );

    expect(response.left.statusCode, 401);
    verify(() => storage.delete(key: StorageKeyEnum.opaqueToken.key)).called(1);
  });

  test('does not read the token for an unknown endpoint', () async {
    await client.get(parameter: const Requests(path: 'items'));

    expect(captured!.headers.containsKey('Authorization'), isFalse);
    verifyNever(() => storage.read(key: StorageKeyEnum.opaqueToken.key));
  });

  test('authenticates sign-out by its path without request metadata', () async {
    when(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
        .thenAnswer((_) async => 'opaque-token');

    await client.delete(
      parameter: const Requests(path: 'authentication/sign-out'),
    );

    expect(captured!.headers['Authorization'], 'Bearer opaque-token');
    verify(() => storage.read(key: StorageKeyEnum.opaqueToken.key)).called(1);
  });

  test(
    'does not authenticate a path resembling a protected endpoint',
    () async {
      await client.get(parameter: const Requests(path: 'expenses-other'));

      expect(captured!.headers.containsKey('Authorization'), isFalse);
      verifyNever(() => storage.read(key: StorageKeyEnum.opaqueToken.key));
    },
  );

  test('does not send the token to an external URL', () async {
    await client.get(
      parameter: const Requests(path: 'https://external.example/expenses'),
    );

    expect(captured!.headers.containsKey('Authorization'), isFalse);
    verifyNever(() => storage.read(key: StorageKeyEnum.opaqueToken.key));
  });

  test('does not send a stale header when secure storage fails', () async {
    when(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
        .thenThrow(StateError('storage unavailable'));

    final response = await client.get(
      parameter: const Requests(path: 'expenses'),
    );

    expect(response.isLeft, isTrue);
    expect(captured, isNull);
  });

  test('removes the token after a protected request returns 401', () async {
    responseStatus = 401;
    when(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
        .thenAnswer((_) async => 'opaque-token');
    when(() => storage.delete(key: StorageKeyEnum.opaqueToken.key))
        .thenAnswer((_) async {});

    final response = await client.get(
      parameter: const Requests(path: 'expenses'),
    );

    expect(response.isLeft, isTrue);
    expect(response.left.statusCode, 401);
    verify(() => storage.delete(key: StorageKeyEnum.opaqueToken.key)).called(1);
  });

  test('does not remove the token for a public 401', () async {
    responseStatus = 401;

    final response = await client.post(
      parameter: const Requests(path: 'authentication/sign-in'),
    );

    expect(response.left.statusCode, 401);
    verifyNever(() => storage.delete(key: StorageKeyEnum.opaqueToken.key));
  });

  test('does not remove the token for a protected 403', () async {
    responseStatus = 403;
    when(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
        .thenAnswer((_) async => 'opaque-token');

    final response = await client.get(
      parameter: const Requests(path: 'expenses'),
    );

    expect(response.left.statusCode, 403);
    verifyNever(() => storage.delete(key: StorageKeyEnum.opaqueToken.key));
  });

  test(
    'does not remove a newer token after an older request returns 401',
    () async {
      responseStatus = 401;
      var reads = 0;
      when(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
          .thenAnswer((_) async => ++reads == 1 ? 'old-token' : 'new-token');

      final response = await client.get(
        parameter: const Requests(path: 'expenses'),
      );

      expect(response.left.statusCode, 401);
      verifyNever(() => storage.delete(key: StorageKeyEnum.opaqueToken.key));
    },
  );

  test('preserves the 401 if secure storage cannot remove the token', () async {
    responseStatus = 401;
    when(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
        .thenAnswer((_) async => 'opaque-token');
    when(() => storage.delete(key: StorageKeyEnum.opaqueToken.key))
        .thenThrow(StateError('storage unavailable'));

    final response = await client.get(
      parameter: const Requests(path: 'expenses'),
    );

    expect(response.left.statusCode, 401);
  });
}
