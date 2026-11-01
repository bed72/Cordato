import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_exception_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/interceptors/session_interceptor.dart';

import '../../../../../support/core/mocks/storage_client_mock.dart';
import '../../../../../support/core/fakes/http_client_adapter_fake.dart';

void main() {
  late Dio dio;
  late int status;
  late String? body;
  late HttpClient client;
  late DioException? failure;
  late RequestOptions? captured;

  setUp(() {
    body = '{}';
    status = 200;
    failure = null;
    captured = null;
    dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/'));

    dio.httpClientAdapter = HttpClientAdapterFake(
      respond: (options) {
        captured = options;
        if (failure case final error?) throw error;

        return ResponseBody.fromString(
          body ?? '',
          status,
          headers: {
            Headers.contentTypeHeader: ['application/vnd.api+json'],
          },
        );
      },
    );

    client = HttpClient(dio: dio);
  });

  tearDown(() => dio.close(force: true));

  test(
    'converts PocketBase field errors preserving order and metadata',
    () async {
      status = 400;
      body = '{"status":400,"message":"Failed to authenticate.","data":{"identity":{"code":"validation_required","message":"Missing required value."},"password":{"code":"validation_required","message":"Missing password."}}}';

      await expectLater(
        client.post(
          parameter: const Requests(
            path: 'collections/users/auth-with-password',
          ),
        ),
        throwsA(
          isA<HttpResponseException>()
              .having((error) => error.status, 'status', 400)
              .having((error) => error.errors.errors.length, 'length', 2)
              .having(
                (error) => error.errors.toEntity().errors.first.code,
                'code',
                'validation_required',
              )
              .having(
                (error) => error.errors.errors.first.title,
                'title',
                'Failed to authenticate.',
              )
              .having(
                (error) => error.errors.errors.first.detail,
                'detail',
                'Missing required value.',
              )
              .having(
                (error) => error.errors.errors.first.pointer,
                'pointer',
                '/identity',
              )
              .having(
                (error) => error.errors.errors.first.parameter,
                'parameter',
                'identity',
              )
              .having(
                (error) => error.errors.errors.last.pointer,
                'last pointer',
                '/password',
              ),
        ),
      );
    },
  );

  test('preserves a PocketBase failure without field errors', () async {
    status = 400;
    body = '{"status":400,"message":"Failed to authenticate.","data":{}}';

    await expectLater(
      client.post(
        parameter: const Requests(path: 'collections/users/auth-with-password'),
      ),
      throwsA(
        isA<HttpResponseException>()
            .having(
              (error) => error.errors.errors.single.detail,
              'detail',
              'Failed to authenticate.',
            )
            .having(
              (error) => error.errors.errors.single.status,
              'status',
              '400',
            )
            .having(
              (error) => error.errors.errors.single.pointer,
              'pointer',
              isNull,
            ),
      ),
    );
  });

  test('sends every HTTP method with its request body', () async {
    final operations = <String, Future<Responses> Function()>{
      'GET': () => client.get(parameter: const Requests(path: 'items')),
      'POST': () => client.post(
        parameter: const Requests(path: 'items', body: {'a': 1}),
      ),
      'PUT': () => client.put(
        parameter: const Requests(path: 'items', body: {'a': 1}),
      ),
      'PATCH': () => client.patch(
        parameter: const Requests(path: 'items', body: {'a': 1}),
      ),
      'DELETE': () => client.delete(parameter: const Requests(path: 'items')),
    };

    for (final entry in operations.entries) {
      expect((await entry.value()).status, 200);
      expect(captured!.method, entry.key);
      expect(captured!.uri.toString(), 'https://example.com/api/items');

      if (entry.key != 'GET' && entry.key != 'DELETE') {
        expect(captured!.data, {'a': 1});
        expect(captured!.contentType, Headers.jsonContentType);
      }
    }
  });

  test(
    'preserves path query and encodes additional query and headers',
    () async {
      body = '{"id":1}';

      final response = await client.get(
        parameter: const Requests(
          path: 'items?existing=1',
          query: {'search': 'a & b'},
          headers: {'X-Request-Id': '123'},
        ),
      );

      expect(response.status, 200);
      expect(response.body, {'id': 1});
      expect(captured!.headers['X-Request-Id'], '123');
      expect(captured!.uri.queryParameters, {
        'existing': '1',
        'search': 'a & b',
      });
    },
  );

  test('accepts 201 and the upper successful status boundary', () async {
    body = '{"data":{"id":"1"}}';

    for (final code in [201, 299]) {
      status = code;

      final response = await client.post(
        parameter: const Requests(path: 'items'),
      );

      expect(response.status, code);
      expect(response.body, {
        'data': {'id': '1'},
      });
    }
  });

  test('rejects the first status outside the successful range', () async {
    status = 300;
    body = '{"errors":[{"title":"Redirecionamento"}]}';

    await expectLater(
      client.get(parameter: const Requests(path: 'items')),
      throwsA(
        isA<HttpResponseException>()
            .having((error) => error.status, 'status', 300)
            .having(
              (error) => error.errors.errors.single.title,
              'title',
              'Redirecionamento',
            ),
      ),
    );
  });

  test('preserves an explicit content type for requests with a body', () async {
    const contentType = 'application/vnd.api+json';

    await client.post(
      parameter: const Requests(
        path: 'items',
        headers: {'Content-Type': contentType},
        body: {
          'data': {'type': 'items'},
        },
      ),
    );

    expect(captured!.contentType, contentType);
    expect(captured!.headers['Content-Type'], contentType);
    expect(captured!.data, {
      'data': {'type': 'items'},
    });
  });

  test('removes only the sent token before throwing a protected 401', () async {
    final storage = StorageClientMock();

    status = 401;
    body = '{"errors":[{"title":"Sessão expirada"}]}';
    dio.interceptors.add(SessionInterceptor(storage: storage));

    when(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
        .thenAnswer((_) async => 'sent-token');
    when(() => storage.delete(key: StorageKeyEnum.opaqueToken.key))
        .thenAnswer((_) async {});

    await expectLater(
      client.get(parameter: const Requests(path: 'expenses')),
      throwsA(
        isA<HttpResponseException>()
            .having((error) => error.status, 'status', 401)
            .having(
              (error) => error.errors.errors.single.title,
              'title',
              'Sessão expirada',
            ),
      ),
    );

    expect(captured!.headers['Authorization'], 'Bearer sent-token');

    verifyNever(() => storage.clear());
    verifyNever(() => storage.delete(key: StorageKeyEnum.userId.key));

    verify(() => storage.delete(key: StorageKeyEnum.opaqueToken.key)).called(1);
  });

  test('preserves a newer token when the sent token receives a 401', () async {
    final storage = StorageClientMock();

    status = 401;
    int reads = 0;

    dio.interceptors.add(SessionInterceptor(storage: storage));

    when(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
        .thenAnswer((_) async => ++reads == 1 ? 'sent-token' : 'new-token');

    await expectLater(
      client.get(parameter: const Requests(path: 'expenses')),
      throwsA(
        isA<HttpResponseException>().having(
          (error) => error.status,
          'status',
          401,
        ),
      ),
    );

    expect(captured!.headers['Authorization'], 'Bearer sent-token');

    verifyNever(() => storage.clear());
    verifyNever(() => storage.delete(key: any(named: 'key')));

    verify(() => storage.read(key: StorageKeyEnum.opaqueToken.key)).called(2);
  });

  test(
    'throws every server error with its status and source metadata',
    () async {
      status = 422;
      body = '{"errors":[{"status":"422","title":"Inválido","detail":"Informe o valor","source":{"pointer":"/data/attributes/amount","parameter":"filter"}},{"detail":"Outro erro"}]}';

      await expectLater(
        client.post(parameter: const Requests(path: 'items')),
        throwsA(
          isA<HttpResponseException>()
              .having((error) => error.status, 'status', 422)
              .having((error) => error.errors.errors.length, 'length', 2)
              .having(
                (error) => error.errors.errors.first.title,
                'title',
                'Inválido',
              )
              .having(
                (error) => error.errors.errors.first.detail,
                'detail',
                'Informe o valor',
              )
              .having(
                (error) => error.errors.errors.first.status,
                'status',
                '422',
              )
              .having(
                (error) => error.errors.errors.first.pointer,
                'pointer',
                '/data/attributes/amount',
              )
              .having(
                (error) => error.errors.errors.first.parameter,
                'parameter',
                'filter',
              )
              .having(
                (error) => error.errors.errors.last.detail,
                'last detail',
                'Outro erro',
              ),
        ),
      );
    },
  );

  test('returns an empty map for an empty successful response', () async {
    body = '';
    status = 204;

    expect(
      (await client.delete(parameter: const Requests(path: 'items'))).body,
      isEmpty,
    );
  });

  test('accepts a 202 response without a body for email resend', () async {
    body = '';
    status = 202;

    final response = await client.post(
      parameter: const Requests(
        path: 'authentication/email-verification/resend',
      ),
    );

    expect(response.status, 202);
    expect(response.body, isEmpty);
    expect(
      captured!.uri.toString(),
      'https://example.com/api/authentication/email-verification/resend',
    );
  });

  test('accepts a decoded null body as an empty map', () async {
    body = 'null';

    final response = await client.get(parameter: const Requests(path: 'items'));

    expect(response.status, 200);
    expect(response.body, isEmpty);
  });

  test('rejects non-object bodies regardless of HTTP status', () async {
    for (final code in [200, 302, 401, 403, 422, 500]) {
      status = code;

      for (final value in ['[]', '1', 'true', '"text"']) {
        body = value;

        await expectLater(
          client.get(parameter: const Requests(path: 'items')),
          throwsA(
            isA<HttpInvalidResponseException>().having(
              (error) => error.status,
              'status',
              code,
            ),
          ),
        );
      }
    }
  });

  test('translates malformed JSON from Dio as an unexpected failure', () async {
    for (final code in [200, 422, 500]) {
      status = code;
      body = '{invalid';

      await expectLater(
        client.get(parameter: const Requests(path: 'items')),
        throwsA(isA<HttpUnexpectedException>()),
      );
    }
  });

  test(
    'classifies transport failures without exposing Dio exceptions',
    () async {
      final cases = <DioExceptionType, HttpExceptionEnum>{
        .cancel: .cancelled,
        .sendTimeout: .timeout,
        .receiveTimeout: .timeout,
        .transformTimeout: .timeout,
        .badCertificate: .connection,
        .connectionError: .connection,
        .connectionTimeout: .timeout,
      };

      for (final entry in cases.entries) {
        failure = DioException(
          type: entry.key,
          requestOptions: RequestOptions(path: 'items'),
        );

        await expectLater(
          client.get(parameter: const Requests(path: 'items')),
          throwsA(
            isA<HttpTransportException>().having(
              (error) => error.failure,
              'failure',
              entry.value,
            ),
          ),
        );
      }
    },
  );

  test(
    'does not disguise unexpected failures as connectivity errors',
    () async {
      final cause = StateError('interceptor failed');

      failure = DioException(
        error: cause,
        requestOptions: RequestOptions(path: 'items'),
      );

      await expectLater(
        client.get(parameter: const Requests(path: 'items')),
        throwsA(isA<HttpUnexpectedException>()),
      );
    },
  );

  test(
    'preserves HTTP status with fallback for invalid error envelopes',
    () async {
      for (final code in [302, 401, 403, 422, 500]) {
        status = code;

        for (final value in [
          '',
          '{}',
          '{"errors":[]}',
          '{"errors":[null]}',
          '{"errors":"invalid"}',
        ]) {
          body = value;

          await expectLater(
            client.get(parameter: const Requests(path: 'items')),
            throwsA(
              isA<HttpResponseException>()
                  .having((error) => error.status, 'status', code)
                  .having(
                    (error) => error.errors.errors.single.title,
                    'title',
                    'Erro desconhecido',
                  ),
            ),
          );
        }
      }
    },
  );

  test(
    'rejects a response with no status without inventing an HTTP code',
    () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onResponse: (response, handler) {
            handler.next(response);
            response.statusCode = null;
          },
        ),
      );

      await expectLater(
        client.get(parameter: const Requests(path: 'items')),
        throwsA(
          isA<HttpInvalidResponseException>().having(
            (error) => error.status,
            'status',
            isNull,
          ),
        ),
      );
    },
  );

  test(
    'translates an unclassified Dio failure without an underlying cause',
    () async {
      failure = DioException(requestOptions: RequestOptions(path: 'items'));

      await expectLater(
        client.get(parameter: const Requests(path: 'items')),
        throwsA(isA<HttpUnexpectedException>()),
      );
    },
  );

  test(
    'translates a Dio rejection outside status validation as unexpected',
    () async {
      failure = DioException(
        type: .badResponse,
        requestOptions: RequestOptions(path: 'items'),
      );

      await expectLater(
        client.get(parameter: const Requests(path: 'items')),
        throwsA(isA<HttpUnexpectedException>()),
      );
    },
  );

  test('keeps unchanged request fields when copying', () {
    const request = Requests(
      path: 'items',
      body: {'a': 1},
      headers: {'x': 'y'},
    );

    final copy = request.copyWith(query: {'page': 2});

    expect(copy.path, 'items');
    expect(copy.body, {'a': 1});
    expect(copy.query, {'page': 2});
    expect(copy.headers, {'x': 'y'});
    expect(copy.copyWith(path: 'other').path, 'other');
  });

  test('uses default HTTP behavior for relative paths', () async {
    await client.get(parameter: const Requests(path: 'expenses'));

    expect(captured!.followRedirects, isTrue);
  });
}
