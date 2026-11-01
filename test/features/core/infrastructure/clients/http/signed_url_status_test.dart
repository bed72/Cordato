import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_exception_enum.dart';
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

  tearDown(() => dio.close(force: true));

  test('sends the original absolute URL without authentication', () async {
    final response = await client.get(parameter: const Requests(path: url));

    expect(request!.method, 'GET');
    expect(request!.uri.toString(), url);
    expect(response.status, 204);
    expect(request!.headers.containsKey('Authorization'), isFalse);

    verifyNever(() => storage.read(key: any(named: 'key')));
  });

  test('preserves failure and redirect response statuses', () async {
    for (final code in [403, 302]) {
      status = code;
      await expectLater(
        client.get(parameter: const Requests(path: url)),
        throwsA(
          isA<HttpResponseException>().having(
            (error) => error.status,
            'status',
            code,
          ),
        ),
      );
    }
  });

  test('throws a transport exception on connection failure', () async {
    connectionFails = true;
    await expectLater(
      client.get(parameter: const Requests(path: url)),
      throwsA(
        isA<HttpTransportException>().having(
          (error) => error.failure,
          'failure',
          HttpExceptionEnum.connection,
        ),
      ),
    );
  });
}
