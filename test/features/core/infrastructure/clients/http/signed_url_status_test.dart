import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/factories/dio_factory.dart';

import '../../../../../support/core/mocks/storage_client_mock.dart';
import '../../../../../support/core/fakes/http_client_adapter_fake.dart';

void main() {
  const url =
      'https://other.example/api/email-verification/12/abc123?expires=123456&signature=abcdef012345';
  late Dio dio;
  late int status;
  late HttpClient client;
  late bool connectionFails;
  late RequestOptions? request;
  late StorageClientMock storage;

  setUp(() {
    storage = StorageClientMock();
    dio = DioFactory.create(
      storage: storage,
      baseUrl: 'https://api.cordato.cloud/api/',
    );
    status = 204;
    request = null;
    connectionFails = false;
    dio.httpClientAdapter = HttpClientAdapterFake(
      respond: (options) {
        request = options;
        if (connectionFails) {
          throw DioException(requestOptions: options, type: .connectionError);
        }
        return ResponseBody.fromString('', status);
      },
    );
    client = HttpClient(dio: dio);
  });

  test('sends the original absolute URL without authentication', () async {
    final response = await client.get(parameter: const Requests(path: url));

    expect(request!.method, 'GET');
    expect(request!.uri.toString(), url);
    expect(response.right.status, 204);
    expect(request!.headers.containsKey('Authorization'), isFalse);

    verifyNever(() => storage.read(key: any(named: 'key')));
  });

  test('preserves failure and redirect response statuses', () async {
    status = 403;
    final forbidden = await client.get(parameter: const Requests(path: url));
    expect(forbidden.left.status, 403);

    status = 302;
    final redirect = await client.get(parameter: const Requests(path: url));
    expect(redirect.left.status, 302);
  });

  test('returns status zero on connection failure', () async {
    connectionFails = true;
    final response = await client.get(parameter: const Requests(path: url));

    expect(response.left.status, 0);
  });
}
