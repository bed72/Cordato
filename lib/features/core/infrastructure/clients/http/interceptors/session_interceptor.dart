import 'package:dio/dio.dart';

import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';

import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';

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
    final base = Uri.parse(options.baseUrl);
    if (Uri.parse(options.path).isAbsolute) return false;
    if (options.uri.origin != base.origin) return false;
    final actual = options.uri.pathSegments;
    for (final endpoint in HttpPathEnum.values) {
      if (!endpoint.authenticated) continue;
      final expected = base.resolve(endpoint.path).pathSegments;
      final hasId = endpoint == HttpPathEnum.user;
      if (actual.length != expected.length + (hasId ? 1 : 0)) continue;
      var matches = true;
      for (var index = 0; index < expected.length; index++) {
        if (actual[index] != expected[index]) {
          matches = false;
          break;
        }
      }
      if (matches &&
          (!hasId ||
              (actual.last.isNotEmpty &&
                  actual.last != '.' &&
                  actual.last != '..'))) {
        return true;
      }
    }
    return false;
  }
}
