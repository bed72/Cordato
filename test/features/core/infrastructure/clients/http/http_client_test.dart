import 'dart:convert';
import 'dart:io' hide HttpClient;

import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/interceptors/origin_interceptor.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_exception_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_method_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';

import '../../../../../support/core/fakes/http_client_adapter_fake.dart';

void main() {
  late Directory directory;
  late Dio transport;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cordato-appwrite-');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  HttpClient createClient({String projectId = 'test-project'}) {
    final cookies = PersistCookieJar(
      ignoreExpires: false,
      persistSession: true,
      storage: FileStorage(directory.path),
    );
    transport =
        Dio(
            BaseOptions(
              baseUrl: 'https://appwrite.example/v1',
              followRedirects: false,
              contentType: Headers.jsonContentType,
              sendTimeout: const Duration(seconds: 20),
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'X-Appwrite-Project': projectId,
                'Accept': Headers.jsonContentType,
              },
            ),
          )
          ..interceptors.addAll([
            OriginInterceptor(origin: Uri.parse('https://appwrite.example/v1')),
            CookieManager(cookies),
          ]);
    final client = HttpClient(dio: transport);
    addTearDown(() => client.close(force: true));
    return client;
  }

  group('Configuration and payloads', () {
    for (final method in HttpMethodEnum.values) {
      test(
        'executes ${method.value} with body, query and request headers',
        () async {
          final client = createClient();
          final adapter = HttpClientAdapterFake();
          transport.httpClientAdapter = adapter;
          const parameter = Requests(
            path: '/resource',
            body: {'name': ' original '},
            query: {'page': 2},
            headers: {'X-Request': 'original'},
          );

          final response = await switch (method) {
            .get => client.get(parameter: parameter),
            .put => client.put(parameter: parameter),
            .post => client.post(parameter: parameter),
            .patch => client.patch(parameter: parameter),
            .delete => client.delete(parameter: parameter),
          };

          expect(response.status, 200);
          expect(response.body, isEmpty);
          final request = adapter.requests.single;
          expect(request.method, method.value);
          expect(request.data, parameter.body);
          expect(request.queryParameters, parameter.query);
          expect(request.headers['X-Request'], 'original');
        },
      );
    }

    test('uses the supplied Dio configuration without replacing it', () async {
      final client = createClient();
      final adapter = HttpClientAdapterFake();
      transport.httpClientAdapter = adapter;

      await client.get(parameter: const Requests(path: '/account'));

      final request = adapter.requests.single;
      expect(request.followRedirects, isFalse);
      expect(request.contentType, Headers.jsonContentType);
      expect(request.sendTimeout, const Duration(seconds: 20));
      expect(request.headers['Accept'], Headers.jsonContentType);
      expect(request.connectTimeout, const Duration(seconds: 15));
      expect(request.receiveTimeout, const Duration(seconds: 20));
      expect(request.headers['X-Appwrite-Project'], 'test-project');
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(request.uri.toString(), 'https://appwrite.example/v1/account');
    });

    test('preserves JSON payload without normalization', () async {
      final client = createClient();
      final adapter = HttpClientAdapterFake();
      transport.httpClientAdapter = adapter;
      final payload = {'email': ' user@example.com ', 'userId': 'unique()'};

      await client.post(
        parameter: Requests(path: '/account/tokens/email', body: payload),
      );

      expect(adapter.requests.single.data, payload);
      expect(adapter.requests.single.method, 'POST');
    });
  });

  group('Cookie persistence', () {
    test('persists session cookies across client recreation', () async {
      final client = createClient();
      final adapter = HttpClientAdapterFake()
        ..respond = (_) => ResponseBody.fromString(
          '{}',
          201,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'set-cookie': [
              'a_session_test-project=fake-session; Path=/; Secure; HttpOnly',
            ],
          },
        );
      transport.httpClientAdapter = adapter;

      await client.post(
        parameter: const Requests(path: '/account/sessions/token'),
      );
      client.close();

      final restored = createClient();
      final restoredAdapter = HttpClientAdapterFake();
      transport.httpClientAdapter = restoredAdapter;
      await restored.get(parameter: const Requests(path: '/account'));

      expect(
        restoredAdapter.requests.single.headers[HttpHeaders.cookieHeader],
        contains('a_session_test-project=fake-session'),
      );
    });

    test('does not send expired cookies', () async {
      final client = createClient();
      final adapter = HttpClientAdapterFake()
        ..respond = (_) => ResponseBody.fromString(
          '{}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'set-cookie': [
              'a_session_test-project=expired; Path=/; Max-Age=0; Secure',
            ],
          },
        );
      transport.httpClientAdapter = adapter;

      await client.post(
        parameter: const Requests(path: '/account/sessions/token'),
      );
      await client.get(parameter: const Requests(path: '/account'));

      expect(adapter.requests.last.headers[HttpHeaders.cookieHeader], isNull);
    });

    test('does not clear persisted cookies on an ordinary 401', () async {
      final client = createClient();
      final adapter = HttpClientAdapterFake()
        ..respond = (_) => ResponseBody.fromString(
          '{}',
          201,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'set-cookie': [
              'a_session_test-project=fake-session; Path=/; Secure; HttpOnly',
            ],
          },
        );
      transport.httpClientAdapter = adapter;
      await client.post(
        parameter: const Requests(path: '/account/sessions/token'),
      );
      adapter.respond = (_) => ResponseBody.fromString('{}', 401);

      await expectLater(
        client.get(parameter: const Requests(path: '/account')),
        throwsA(isA<HttpResponseException>()),
      );

      final restored = createClient();
      final restoredAdapter = HttpClientAdapterFake();
      transport.httpClientAdapter = restoredAdapter;
      await restored.get(parameter: const Requests(path: '/account'));

      expect(
        restoredAdapter.requests.single.headers[HttpHeaders.cookieHeader],
        contains('a_session_test-project=fake-session'),
      );
    });
  });

  group('Transport and origin restriction', () {
    for (final scenario in [
      (type: DioExceptionType.cancel, failure: HttpExceptionEnum.cancelled),
      (
        type: DioExceptionType.connectionError,
        failure: HttpExceptionEnum.connection,
      ),
      (
        type: DioExceptionType.badCertificate,
        failure: HttpExceptionEnum.connection,
      ),
      (
        type: DioExceptionType.connectionTimeout,
        failure: HttpExceptionEnum.timeout,
      ),
      (type: DioExceptionType.sendTimeout, failure: HttpExceptionEnum.timeout),
      (
        type: DioExceptionType.transformTimeout,
        failure: HttpExceptionEnum.timeout,
      ),
    ]) {
      test(
        'maps ${scenario.type} to ${scenario.failure} without exposing Dio',
        () async {
          final client = createClient();
          final adapter = HttpClientAdapterFake()
            ..respond = (request) => throw DioException(
              requestOptions: request,
              type: scenario.type,
            );
          transport.httpClientAdapter = adapter;

          await expectLater(
            client.get(parameter: const Requests(path: '/account')),
            throwsA(
              isA<HttpTransportException>().having(
                (exception) => exception.failure,
                'failure',
                scenario.failure,
              ),
            ),
          );

          expect(adapter.requests, hasLength(1));
        },
      );
    }

    for (final failure in [
      StateError('unexpected'),
      const FormatException('malformed'),
    ]) {
      test(
        'propagates unexpected ${failure.runtimeType} without masking',
        () async {
          final client = createClient();
          transport.httpClientAdapter = HttpClientAdapterFake()
            ..respond = (_) => throw failure;

          await expectLater(
            client.get(parameter: const Requests(path: '/account')),
            throwsA(same(failure)),
          );
        },
      );
    }

    for (final body in [null, '', '<html>Unavailable</html>', []]) {
      test('preserves failing HTTP status for non-object body $body', () async {
        final client = createClient();
        transport.httpClientAdapter = HttpClientAdapterFake()
          ..respond = (_) => ResponseBody.fromString(
            jsonEncode(body),
            503,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );

        await expectLater(
          client.get(parameter: const Requests(path: '/account')),
          throwsA(
            isA<HttpResponseException>().having(
              (exception) => exception.response.status,
              'status',
              503,
            ),
          ),
        );
      });
    }

    test(
      'does not turn an invalid successful envelope into an empty object',
      () async {
        final client = createClient();
        transport.httpClientAdapter = HttpClientAdapterFake()
          ..respond = (_) => ResponseBody.fromString(
            '[]',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );

        await expectLater(
          client.get(parameter: const Requests(path: '/account')),
          throwsA(isA<HttpInvalidResponseException>()),
        );
      },
    );

    test('propagates transport timeout without retry', () async {
      final client = createClient();
      final adapter = HttpClientAdapterFake()
        ..respond = (request) =>
            throw DioException(requestOptions: request, type: .receiveTimeout);
      transport.httpClientAdapter = adapter;

      await expectLater(
        client.get(parameter: const Requests(path: '/account')),
        throwsA(
          isA<HttpTransportException>().having(
            (exception) => exception.failure,
            'failure',
            HttpExceptionEnum.timeout,
          ),
        ),
      );

      expect(adapter.requests, hasLength(1));
    });

    test('rejects another origin before reaching transport', () async {
      final client = createClient();
      final adapter = HttpClientAdapterFake();
      transport.httpClientAdapter = adapter;

      await expectLater(
        client.get(
          parameter: const Requests(path: 'https://other.example/account'),
        ),
        throwsArgumentError,
      );

      expect(adapter.requests, isEmpty);
    });

    test('keeps HTTP failures as own exceptions without retry', () async {
      final client = createClient();
      final adapter = HttpClientAdapterFake()
        ..respond = (_) => ResponseBody.fromString('{}', 401);
      transport.httpClientAdapter = adapter;

      await expectLater(
        client.get(parameter: const Requests(path: '/account')),
        throwsA(
          isA<HttpResponseException>().having(
            (exception) => exception.response.status,
            'status',
            401,
          ),
        ),
      );

      expect(adapter.requests, hasLength(1));
    });
  });
}
