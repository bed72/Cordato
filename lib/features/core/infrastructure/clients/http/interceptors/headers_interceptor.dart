import 'package:dio/dio.dart';

final class HeadersInterceptor extends Interceptor {
  static const mediaType = 'application/vnd.api+json';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final contentType = options.uri.pathSegments.contains('collections')
        ? Headers.jsonContentType
        : mediaType;

    options.headers.putIfAbsent(Headers.acceptHeader, () => contentType);
    if (options.data != null) options.contentType = contentType;

    handler.next(options);
  }
}
