import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/interceptors/headers_interceptor.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';

void main() {
  test('adds JSON:API headers to requests with a body', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/'))
      ..interceptors.add(HeadersInterceptor());
    RequestOptions? captured;
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
    final client = HttpClient(dio: dio);

    await client.post(
      parameter: const Requests(
        'authentication/sign-in',
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
    RequestOptions? captured;
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
    final client = HttpClient(dio: dio);

    await client.get(parameter: const Requests('items'));

    expect(
      captured!.headers[Headers.acceptHeader],
      HeadersInterceptor.mediaType,
    );
    expect(captured!.contentType, isNull);
  });
}
