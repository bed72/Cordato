import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/interceptors/headers_interceptor.dart';

void main() {
  late Dio dio;
  late HttpClient client;
  late RequestOptions? captured;

  setUp(() {
    captured = null;
    dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/'))
      ..interceptors.add(HeadersInterceptor());

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(
            Response<Map<String, dynamic>>(
              data: {},
              statusCode: 200,
              requestOptions: options,
            ),
          );
        },
      ),
    );
    client = HttpClient(dio: dio);
  });

  tearDown(() => dio.close(force: true));

  test('uses JSON headers for PocketBase collection requests', () async {
    for (final path in [
      'collections/users/records',
      'collections/users/auth-with-password',
      'collections/users/request-verification',
      'collections/users/confirm-verification',
    ]) {
      await client.post(
        parameter: Requests(
          path: path,
          body: const {'email': 'test@example.com'},
        ),
      );

      expect(captured!.contentType, Headers.jsonContentType);
      expect(captured!.uri.toString(), 'https://example.com/api/$path');
      expect(captured!.headers[Headers.acceptHeader], Headers.jsonContentType);
    }
  });

  test('adds JSON:API headers to requests with a body', () async {
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
    await client.get(parameter: const Requests(path: 'items'));

    expect(
      captured!.headers[Headers.acceptHeader],
      HeadersInterceptor.mediaType,
    );
    expect(captured!.contentType, isNull);
  });
}
