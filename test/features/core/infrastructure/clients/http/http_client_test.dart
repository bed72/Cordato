import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/error_response.dart';

void main() {
  late Dio dio;
  late HttpClient client;
  late RequestOptions? captured;
  late String? body;
  late int status;
  late DioException? failure;

  setUp(() {
    captured = null;
    body = '{}';
    status = 200;
    failure = null;
    dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          if (failure case final error?) {
            handler.reject(error);
          } else {
            handler.resolve(
              Response<String>(
                requestOptions: options,
                statusCode: status,
                data: body,
              ),
            );
          }
        },
      ),
    );
    client = HttpClient(baseUrl: 'https://example.com/api/', dio: dio);
  });

  test('sends every HTTP method with its request body', () async {
    final operations = <String, Future<dynamic> Function()>{
      'GET': () => client.get(parameter: const Requests('items')),
      'POST': () =>
          client.post(parameter: const Requests('items', body: {'a': 1})),
      'PUT': () =>
          client.put(parameter: const Requests('items', body: {'a': 1})),
      'PATCH': () =>
          client.patch(parameter: const Requests('items', body: {'a': 1})),
      'DELETE': () => client.delete(parameter: const Requests('items')),
    };

    for (final entry in operations.entries) {
      expect((await entry.value()).isRight, isTrue);
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

      final result = await client.get(
        parameter: const Requests(
          'items?existing=1',
          query: {'search': 'a & b'},
          headers: {'X-Request-Id': '123'},
        ),
      );

      expect(result.right, {'id': 1});
      expect(captured!.uri.queryParameters, {
        'existing': '1',
        'search': 'a & b',
      });
      expect(captured!.headers['X-Request-Id'], '123');
    },
  );

  test('returns server error body for non-success status', () async {
    status = 422;
    body = '{"errors":[{"code":"invalid"}]}';

    final result = await client.post(parameter: const Requests('items'));

    expect(result.left, {
      'errors': [
        {'code': 'invalid'},
      ],
    });
  });

  test('returns an empty map for an empty successful response', () async {
    status = 204;
    body = '';

    expect(
      (await client.delete(parameter: const Requests('items'))).right,
      isEmpty,
    );
  });

  test('returns a network failure for a Dio transport exception', () async {
    failure = DioException(
      requestOptions: RequestOptions(path: 'items'),
      type: DioExceptionType.connectionError,
      message: 'offline',
    );

    final result = await client.get(parameter: const Requests('items'));

    final error = ErrorsResponse.fromJson(result.left).errors.single;
    expect(error.title, 'Erro de rede');
    expect(error.detail, 'offline');
    expect(error.status, isNull);
    expect(error.pointer, isNull);
  });

  test(
    'uses a default detail when the transport provides no message',
    () async {
      failure = DioException(
        requestOptions: RequestOptions(path: 'items'),
        type: DioExceptionType.connectionError,
      );

      final result = await client.get(parameter: const Requests('items'));

      final error = ErrorsResponse.fromJson(result.left).errors.single;
      expect(error.title, 'Erro de rede');
      expect(error.detail, isNotEmpty);
    },
  );

  test('uses the error envelope for a non-object server response', () async {
    status = 500;
    body = '[]';

    final result = await client.get(parameter: const Requests('items'));

    final error = ErrorsResponse.fromJson(result.left).errors.single;
    expect(error.title, 'Erro de rede');
  });

  test('returns an unknown failure for malformed JSON', () async {
    body = '{invalid';

    final result = await client.get(parameter: const Requests('items'));

    final error = ErrorsResponse.fromJson(result.left).errors.single;
    expect(error.title, 'Erro desconhecido');
    expect(error.detail, 'Não foi possível processar a resposta.');
    expect(error.status, isNull);
    expect(error.pointer, isNull);
  });

  test('keeps unchanged request fields when copying', () {
    const request = Requests('items', body: {'a': 1}, headers: {'x': 'y'});

    final copy = request.copyWith(query: {'page': 2});

    expect(copy.path, 'items');
    expect(copy.body, {'a': 1});
    expect(copy.headers, {'x': 'y'});
    expect(copy.query, {'page': 2});
  });
}
