import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/interceptors/headers_interceptor.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';

void main() {
  test('uses JSON headers for PocketBase collection requests', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/'))
      ..interceptors.add(HeadersInterceptor());
    addTearDown(() => dio.close(force: true));
    RequestOptions? captured;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {},
            ),
          );
        },
      ),
    );

    for (final path in [
      'collections/users/auth-with-password',
      'collections/users/records',
      'collections/users/request-verification',
      'collections/users/confirm-verification',
    ]) {
      await HttpClient(dio: dio).post(
        parameter: Requests(
          path: path,
          body: const {'email': 'test@example.com'},
        ),
      );

      expect(captured!.uri.toString(), 'https://example.com/api/$path');
      expect(captured!.headers[Headers.acceptHeader], Headers.jsonContentType);
      expect(captured!.contentType, Headers.jsonContentType);
    }
  });

  test('adds JSON:API headers to requests with a body', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/'))
      ..interceptors.add(HeadersInterceptor());
    addTearDown(() => dio.close(force: true));
    RequestOptions? captured;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {},
            ),
          );
        },
      ),
    );
    final client = HttpClient(dio: dio);

    await client.post(
      parameter: const Requests(
        path: 'authentication/sign-in',
        body: {
          'data': {'type': 'access-tokens'},
        },
      ),
    );

    expect(
      captured!.headers[Headers.acceptHeader],
      HeadersInterceptor.mediaType,
    );
    expect(captured!.contentType, HeadersInterceptor.mediaType);
  });

  test('adds Accept without inventing a Content-Type for GET', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/'))
      ..interceptors.add(HeadersInterceptor());
    addTearDown(() => dio.close(force: true));
    RequestOptions? captured;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {},
            ),
          );
        },
      ),
    );
    final client = HttpClient(dio: dio);

    await client.get(parameter: const Requests(path: 'items'));

    expect(
      captured!.headers[Headers.acceptHeader],
      HeadersInterceptor.mediaType,
    );
    expect(captured!.contentType, isNull);
  });
}
