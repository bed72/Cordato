import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/interceptors/session_interceptor.dart';

class _StorageClientMock extends Mock implements IStorageClient {}

void main() {
  late _StorageClientMock storage;
  late HttpClient client;
  late int responseStatus;
  late RequestOptions? captured;

  setUp(() {
    storage = _StorageClientMock();
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

    await client.get(parameter: Requests.forPath(HttpPathEnum.expenses));

    expect(captured!.headers['Authorization'], 'Bearer opaque-token');
    verify(() => storage.read(key: StorageKeyEnum.opaqueToken.key)).called(1);

    await client.post(parameter: Requests.forPath(HttpPathEnum.signIn));

    expect(captured!.headers.containsKey('Authorization'), isFalse);
    verifyNever(() => storage.read(key: StorageKeyEnum.opaqueToken.key));
  });

  test('does not send Authorization without a saved token', () async {
    when(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
        .thenAnswer((_) async => null);

    await client.get(parameter: Requests.forPath(HttpPathEnum.expenses));

    expect(captured!.headers.containsKey('Authorization'), isFalse);
  });

  test('does not read the token for an unclassified request', () async {
    await client.get(parameter: const Requests('expenses'));

    expect(captured!.headers.containsKey('Authorization'), isFalse);
    verifyNever(() => storage.read(key: StorageKeyEnum.opaqueToken.key));
  });

  test('does not read the token when the route differs from the URL', () async {
    await client.get(
      parameter: const Requests('expenses', route: HttpPathEnum.signIn),
    );

    expect(captured!.headers.containsKey('Authorization'), isFalse);
    verifyNever(() => storage.read(key: StorageKeyEnum.opaqueToken.key));
  });

  test('does not send the token to an external URL', () async {
    await client.get(
      parameter: const Requests(
        'https://external.example/items',
        route: HttpPathEnum.expenses,
      ),
    );

    expect(captured!.headers.containsKey('Authorization'), isFalse);
    verifyNever(() => storage.read(key: StorageKeyEnum.opaqueToken.key));
  });

  test('does not send a stale header when secure storage fails', () async {
    when(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
        .thenThrow(StateError('storage unavailable'));

    final response = await client.get(
      parameter: Requests.forPath(HttpPathEnum.expenses),
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
      parameter: Requests.forPath(HttpPathEnum.expenses),
    );

    expect(response.isLeft, isTrue);
    expect(response.left.statusCode, 401);
    verify(() => storage.delete(key: StorageKeyEnum.opaqueToken.key)).called(1);
  });

  test('does not remove the token for a public 401', () async {
    responseStatus = 401;

    final response = await client.post(
      parameter: Requests.forPath(HttpPathEnum.signIn),
    );

    expect(response.left.statusCode, 401);
    verifyNever(() => storage.delete(key: StorageKeyEnum.opaqueToken.key));
  });

  test('does not remove the token for a protected 403', () async {
    responseStatus = 403;
    when(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
        .thenAnswer((_) async => 'opaque-token');

    final response = await client.get(
      parameter: Requests.forPath(HttpPathEnum.expenses),
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
        parameter: Requests.forPath(HttpPathEnum.expenses),
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
      parameter: Requests.forPath(HttpPathEnum.expenses),
    );

    expect(response.left.statusCode, 401);
  });
}
