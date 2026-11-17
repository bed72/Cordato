import 'dart:io' hide HttpClient;

import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';

import '../../../../../support/core/fakes/http_client_adapter_fake.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cordato-appwrite-');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  Dio createClient({String projectId = 'test-project'}) {
    final cookies = PersistCookieJar(
      ignoreExpires: false,
      persistSession: true,
      storage: FileStorage(directory.path),
    );
    final client = HttpClient.create(
      cookies: cookies,
      endpoint: 'https://appwrite.example/v1',
      projectId: projectId,
    );
    addTearDown(() => client.close(force: true));
    return client;
  }

  group('Configuration and payloads', () {
    test('configures project, JSON, timeouts and disables redirects', () async {
      final client = createClient();
      final adapter = HttpClientAdapterFake();
      client.httpClientAdapter = adapter;

      await client.get<dynamic>('/account');

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
      client.httpClientAdapter = adapter;
      final payload = {'email': ' user@example.com ', 'userId': 'unique()'};

      await client.post<dynamic>('/account/tokens/email', data: payload);

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
      client.httpClientAdapter = adapter;

      await client.post<dynamic>('/account/sessions/token');
      client.close();

      final restored = createClient();
      final restoredAdapter = HttpClientAdapterFake();
      restored.httpClientAdapter = restoredAdapter;
      await restored.get<dynamic>('/account');

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
            'set-cookie': [
              'a_session_test-project=expired; Path=/; Max-Age=0; Secure',
            ],
          },
        );
      client.httpClientAdapter = adapter;

      await client.post<dynamic>('/account/sessions/token');
      await client.get<dynamic>('/account');

      expect(adapter.requests.last.headers[HttpHeaders.cookieHeader], isNull);
    });

    test('does not clear persisted cookies on an ordinary 401', () async {
      final client = createClient();
      final adapter = HttpClientAdapterFake()
        ..respond = (_) => ResponseBody.fromString(
          '{}',
          201,
          headers: {
            'set-cookie': [
              'a_session_test-project=fake-session; Path=/; Secure; HttpOnly',
            ],
          },
        );
      client.httpClientAdapter = adapter;
      await client.post<dynamic>('/account/sessions/token');
      adapter.respond = (_) => ResponseBody.fromString('{}', 401);

      await expectLater(
        client.get<dynamic>('/account'),
        throwsA(isA<DioException>()),
      );

      final restored = createClient();
      final restoredAdapter = HttpClientAdapterFake();
      restored.httpClientAdapter = restoredAdapter;
      await restored.get<dynamic>('/account');

      expect(
        restoredAdapter.requests.single.headers[HttpHeaders.cookieHeader],
        contains('a_session_test-project=fake-session'),
      );
    });
  });

  group('Transport and origin restriction', () {
    test('propagates transport timeout without retry', () async {
      final client = createClient();
      final adapter = HttpClientAdapterFake()
        ..respond = (request) =>
            throw DioException(requestOptions: request, type: .receiveTimeout);
      client.httpClientAdapter = adapter;

      await expectLater(
        client.get<dynamic>('/account'),
        throwsA(
          isA<DioException>().having(
            (exception) => exception.type,
            'type',
            DioExceptionType.receiveTimeout,
          ),
        ),
      );

      expect(adapter.requests, hasLength(1));
    });

    test('rejects another origin before reaching transport', () async {
      final client = createClient();
      final adapter = HttpClientAdapterFake();
      client.httpClientAdapter = adapter;

      await expectLater(
        client.get<dynamic>('https://other.example/account'),
        throwsA(isA<DioException>()),
      );

      expect(adapter.requests, isEmpty);
    });

    test('keeps HTTP failures as Dio exceptions without retry', () async {
      final client = createClient();
      final adapter = HttpClientAdapterFake()
        ..respond = (_) => ResponseBody.fromString('{}', 401);
      client.httpClientAdapter = adapter;

      await expectLater(
        client.get<dynamic>('/account'),
        throwsA(
          isA<DioException>().having(
            (exception) => exception.response?.statusCode,
            'status',
            401,
          ),
        ),
      );

      expect(adapter.requests, hasLength(1));
    });
  });
}
