import 'package:dio/dio.dart';

import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';

import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_extra_key_enum.dart';

final class SessionInterceptor({required final IStorageClient storage})
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
      final token = await storage.read(key: StorageKeyEnum.opaqueToken.key);
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

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final options = response.requestOptions;

    if (response.statusCode == 401 && _requiresToken(options)) {
      try {
        final token = await storage.read(key: StorageKeyEnum.opaqueToken.key);

        if (token != null &&
            options.headers['Authorization'] == 'Bearer $token') {
          await storage.delete(key: StorageKeyEnum.opaqueToken.key);
        }
      } catch (_) {}
    }

    handler.next(response);
  }

  bool _requiresToken(RequestOptions options) {
    final route = options.extra[HttpExtraKeyEnum.route.key];
    if (route is! HttpPathEnum || !route.requiresAuth) return false;

    final base = Uri.parse(options.baseUrl);
    return options.uri.origin == base.origin &&
        options.uri.path == base.resolve(route.path).path;
  }
}
