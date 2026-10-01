import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/authentication/infrastructure/clients/email_verification_client.dart';

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
      'https://api.cordato.cloud/api/email-verification/12/abc123?expires=123456&signature=abcdef012345';
  late Dio dio;
  late int status;
  late RequestOptions? request;
  late EmailVerificationClient client;

  setUp(() {
    dio = Dio();
    status = 204;
    request = null;
    dio.httpClientAdapter = _TestAdapter(
      respond: (options) {
        request = options;
        return ResponseBody.fromString('', status);
      },
    );
    client = EmailVerificationClient(dio: dio);
  });

  test(
    'uses original signed URL with GET, no authorization or redirects',
    () async {
      expect(await client.confirm(url), 204);
      expect(request!.uri.toString(), url);
      expect(request!.method, 'GET');
      expect(request!.headers.containsKey('Authorization'), isFalse);
      expect(request!.followRedirects, isFalse);
    },
  );

  test('returns 403 without following a redirect', () async {
    status = 403;
    expect(await client.confirm(url), 403);
  });
}
