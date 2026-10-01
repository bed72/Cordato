import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

import 'package:cordato/features/core/infrastructure/clients/http/factories/dio_factory.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_extra_key_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/storage_client.dart';

class _StorageClientMock extends Mock implements IStorageClient {}

final class _TestAdapter({
  required final ResponseBody Function(RequestOptions) respond,
}) implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);

  @override
  void close({bool force = false}) {}
}

void main() {
  const url =
      'https://other.example/api/email-verification/12/abc123?expires=123456&signature=abcdef012345';
  late Dio dio;
  late int status;
  late RequestOptions? request;
  late HttpClient client;
  late _StorageClientMock storage;
  late bool connectionFails;

  setUp(() {
    storage = _StorageClientMock();
    dio = DioFactory.create(
      baseUrl: 'https://api.cordato.cloud/api/',
      storage: storage,
    );
    status = 204;
    request = null;
    connectionFails = false;
    dio.httpClientAdapter = _TestAdapter(
      respond: (options) {
        request = options;
        if (connectionFails) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }
        return ResponseBody.fromString('', status);
      },
    );
    client = HttpClient(dio: dio);
  });

  test('sends the original URL without auth or redirects', () async {
    final response = await client.get(
      parameter: const Requests(url, followRedirects: false, logRequest: false),
    );
    expect(response.right.statusCode, 204);
    expect(request!.uri.toString(), url);
    expect(request!.method, 'GET');
    expect(request!.headers.containsKey('Authorization'), isFalse);
    expect(request!.followRedirects, isFalse);
    expect(request!.extra[HttpExtraKeyEnum.skipLogging.key], isTrue);
    verifyNever(() => storage.read(key: any(named: 'key')));
  });

  test('returns the response status without following redirects', () async {
    status = 403;
    final forbidden = await client.get(
      parameter: const Requests(url, followRedirects: false, logRequest: false),
    );
    expect(forbidden.left.statusCode, 403);
    status = 302;
    final redirect = await client.get(
      parameter: const Requests(url, followRedirects: false, logRequest: false),
    );
    expect(redirect.left.statusCode, 302);
    expect(request!.followRedirects, isFalse);
  });

  test('returns null on connection failure', () async {
    connectionFails = true;
    final response = await client.get(
      parameter: const Requests(url, followRedirects: false, logRequest: false),
    );
    expect(response.left.statusCode, 0);
  });

  test(
    'keeps the signed URL out of request, response and error logs',
    () async {
      await client.get(
        parameter: const Requests(
          url,
          followRedirects: false,
          logRequest: false,
        ),
      );
      final logger = dio.interceptors.whereType<TalkerDioLogger>().single;
      final options = request!;
      expect(logger.settings.requestFilter!(options), isFalse);
      expect(
        logger.settings.responseFilter!(
          Response<void>(requestOptions: options, statusCode: 204),
        ),
        isFalse,
      );
      expect(
        logger.settings.errorFilter!(DioException(requestOptions: options)),
        isFalse,
      );
    },
  );
}
