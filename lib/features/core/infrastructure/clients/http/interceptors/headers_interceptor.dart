import 'package:dio/dio.dart';

final class HeadersInterceptor extends Interceptor {
  static const mediaType = 'application/vnd.api+json';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent(Headers.acceptHeader, () => mediaType);
    if (options.data != null) options.contentType = mediaType;

    handler.next(options);
  }
}
