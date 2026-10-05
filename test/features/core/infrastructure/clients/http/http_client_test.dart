import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

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

  test('sends every HTTP method with its request body', () async {
    final operations = <String, Future<dynamic> Function()>{
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

      final response = await client.get(
        parameter: const Requests(
          path: 'items?existing=1',
          query: {'search': 'a & b'},
          headers: {'X-Request-Id': '123'},
        ),
      );

      expect(response.right.body, {'id': 1});
      expect(response.right.statusCode, 200);
      expect(captured!.headers['X-Request-Id'], '123');
      expect(captured!.uri.queryParameters, {
        'existing': '1',
        'search': 'a & b',
      });
    },
  );

  test('returns server error body for non-success status', () async {
    status = 422;
    body = '{"errors":[{"code":"invalid"}]}';

    final response = await client.post(
      parameter: const Requests(path: 'items'),
    );

    expect(response.left.statusCode, 422);
    expect(response.left.body, {
      'errors': [
        {'code': 'invalid'},
      ],
    });
  });

  test('returns an empty map for an empty successful response', () async {
    body = '';
    status = 204;

    expect(
      (await client.delete(parameter: const Requests(path: 'items')))
          .right
          .body,
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

    expect(response.right.body, isEmpty);
    expect(response.right.statusCode, 202);
    expect(
      captured!.uri.toString(),
      'https://example.com/api/authentication/email-verification/resend',
    );
  });

  test('rejects a successful response that is not a JSON object', () async {
    body = '[]';

    final response = await client.get(parameter: const Requests(path: 'items'));

    expect(response.isLeft, isTrue);
  });

  test('returns an unknown failure for a Dio transport exception', () async {
    failure = DioException(
      message: 'offline',
      type: .connectionError,
      requestOptions: RequestOptions(path: 'items'),
    );

    final response = await client.get(parameter: const Requests(path: 'items'));

    expect(response.left.statusCode, 0);
    final error = ErrorsResponse.fromJson(response.left.body).errors.single;

    expect(error.status, isNull);
    expect(error.pointer, isNull);
    expect(error.title, 'Erro desconhecido');
    expect(error.detail, 'Não foi possível processar a resposta.');
  });

  test(
    'uses a default detail when the transport provides no message',
    () async {
      failure = DioException(
        type: .connectionError,
        requestOptions: RequestOptions(path: 'items'),
      );

      final response = await client.get(
        parameter: const Requests(path: 'items'),
      );

      final error = ErrorsResponse.fromJson(response.left.body).errors.single;

      expect(error.detail, isNotEmpty);
      expect(error.title, 'Erro desconhecido');
    },
  );

  test('uses the error envelope for a non-object server response', () async {
    body = '[]';
    status = 500;

    final response = await client.get(parameter: const Requests(path: 'items'));

    final error = ErrorsResponse.fromJson(response.left.body).errors.single;

    expect(error.title, 'Erro desconhecido');
  });

  test('returns an unknown failure for malformed JSON', () async {
    body = '{invalid';

    final response = await client.get(parameter: const Requests(path: 'items'));

    final error = ErrorsResponse.fromJson(response.left.body).errors.single;

    expect(error.status, isNull);
    expect(error.pointer, isNull);
    expect(error.title, 'Erro desconhecido');
    expect(error.detail, 'Não foi possível processar a resposta.');
  });

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
