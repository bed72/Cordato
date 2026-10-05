import 'dart:typed_data';

import 'package:dio/dio.dart';

final class HttpClientAdapterFake({
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
