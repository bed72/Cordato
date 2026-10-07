import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show listEquals;

import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';

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

    return HttpPathEnum.values.any(
      (endpoint) =>
          endpoint.authenticated &&
          _matches(
            endpoint: endpoint,
            actual: options.uri.pathSegments,
            expected: base.resolve(endpoint.path).pathSegments,
          ),
    );
  }

  bool _matches({
    required List<String> actual,
    required HttpPathEnum endpoint,
    required List<String> expected,
  }) {
    if (!endpoint.requiresId && listEquals(actual, expected)) return true;
    if (!endpoint.requiresId && !endpoint.acceptsId) return false;
    if (actual.length != expected.length + 1) return false;

    final id = actual.last;
    return id.isNotEmpty &&
        id != '.' &&
        id != '..' &&
        listEquals(actual.sublist(0, expected.length), expected);
  }
}
