import 'dart:typed_data';

import 'package:dio/dio.dart';

final class HttpClientAdapterFake implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  ResponseBody Function(RequestOptions) respond = (_) =>
      ResponseBody.fromString(
        '{}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}
