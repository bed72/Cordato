import 'package:dio/dio.dart';

final class OriginInterceptor({required final Uri origin}) extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.uri.origin != origin.origin) {
      handler.reject(
        DioException(
          type: .cancel,
          requestOptions: options,
          error: ArgumentError('Origem diferente do Appwrite configurado'),
        ),
      );
      return;
    }

    handler.next(options);
  }
}
