import 'package:dio/dio.dart';

import 'package:cordato/features/core/infrastructure/clients/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/enums/storage_key_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_extra_key_enum.dart';

final class OpaqueTokenInterceptor({required final IStorageClient storage})
    extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_requiresToken(options)) {
      handler.next(options);
      return;
    }

    try {
      final token = await storage.read(key: StorageKeyEnum.accessToken.key);
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }

      handler.next(options);
    } catch (error, stackTrace) {
      handler.reject(
        DioException(
          error: error,
          type: .unknown,
          stackTrace: stackTrace,
          requestOptions: options,
        ),
      );
    }
  }

  bool _requiresToken(RequestOptions options) {
    final route = options.extra[HttpExtraKeyEnum.route.key];
    if (route is! HttpPathEnum || !route.requiresAuth) return false;

    final base = Uri.parse(options.baseUrl);
    return options.uri.origin == base.origin &&
        options.uri.path == base.resolve(route.path).path;
  }
}
