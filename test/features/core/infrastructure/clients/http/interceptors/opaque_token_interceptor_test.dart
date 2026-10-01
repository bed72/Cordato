import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/interceptors/opaque_token_interceptor.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/enums/storage_key_enum.dart';

class _StorageClientMock extends Mock implements IStorageClient {}

void main() {
  late _StorageClientMock storage;
  late HttpClient client;
  late RequestOptions? captured;

  setUp(() {
    storage = _StorageClientMock();
    captured = null;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/'))
      ..interceptors.add(OpaqueTokenInterceptor(storage: storage));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(
            Response<String>(
              requestOptions: options,
              statusCode: 200,
              data: '{}',
            ),
          );
        },
      ),
    );
    client = HttpClient(dio: dio);
  });

  test('adds the stored bearer token only to protected requests', () async {
    when(() => storage.read(key: StorageKeyEnum.accessToken.key))
        .thenAnswer((_) async => 'opaque-token');

    await client.get(parameter: Requests.forPath(HttpPathEnum.expenses));

    expect(captured!.headers['Authorization'], 'Bearer opaque-token');
    verify(() => storage.read(key: StorageKeyEnum.accessToken.key)).called(1);

    await client.post(parameter: Requests.forPath(HttpPathEnum.signIn));

    expect(captured!.headers.containsKey('Authorization'), isFalse);
    verifyNever(() => storage.read(key: StorageKeyEnum.accessToken.key));
  });

  test('does not send Authorization without a saved token', () async {
    when(() => storage.read(key: StorageKeyEnum.accessToken.key))
        .thenAnswer((_) async => null);

    await client.get(parameter: Requests.forPath(HttpPathEnum.expenses));

    expect(captured!.headers.containsKey('Authorization'), isFalse);
  });

  test('does not read the token for an unclassified request', () async {
    await client.get(parameter: const Requests('expenses'));

    expect(captured!.headers.containsKey('Authorization'), isFalse);
    verifyNever(() => storage.read(key: StorageKeyEnum.accessToken.key));
  });

  test('does not read the token when the route differs from the URL', () async {
    await client.get(
      parameter: const Requests('expenses', route: HttpPathEnum.signIn),
    );

    expect(captured!.headers.containsKey('Authorization'), isFalse);
    verifyNever(() => storage.read(key: StorageKeyEnum.accessToken.key));
  });

  test('does not send the token to an external URL', () async {
    await client.get(
      parameter: const Requests(
        'https://external.example/items',
        route: HttpPathEnum.expenses,
      ),
    );

    expect(captured!.headers.containsKey('Authorization'), isFalse);
    verifyNever(() => storage.read(key: StorageKeyEnum.accessToken.key));
  });

  test('does not send a stale header when secure storage fails', () async {
    when(() => storage.read(key: StorageKeyEnum.accessToken.key))
        .thenThrow(StateError('storage unavailable'));

    final response = await client.get(
      parameter: Requests.forPath(HttpPathEnum.expenses),
    );

    expect(response.isLeft, isTrue);
    expect(captured, isNull);
  });
}
