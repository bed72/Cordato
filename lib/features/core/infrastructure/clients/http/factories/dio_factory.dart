import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

import 'package:cordato/features/core/infrastructure/clients/logger/logger_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/interceptors/headers_interceptor.dart';
import 'package:cordato/features/core/infrastructure/clients/http/interceptors/session_interceptor.dart';

final class DioFactory {
  const DioFactory._();

  static Dio create({
    required String baseUrl,
    required IStorageClient storage,
  }) {
    final dio = Dio(
      BaseOptions(baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
    );

    dio.interceptors.addAll([
      HeadersInterceptor(),
      SessionInterceptor(storage: storage),
      if (kDebugMode)
        TalkerDioLogger(
          talker: loggerClient,
          settings: TalkerDioLoggerSettings(
            printErrorData: kDebugMode,
            printRequestData: kDebugMode,
            printResponseData: kDebugMode,
            printErrorHeaders: kDebugMode,
            printRequestHeaders: kDebugMode,
            printResponseHeaders: kDebugMode,
            printResponseMessage: kDebugMode,
            hiddenHeaders: const {'Authorization'},
            requestFilter: _canLog,
            responseFilter: (response) => _canLog(response.requestOptions),
            errorFilter: (error) => _canLog(error.requestOptions),
          ),
        ),
    ]);

    return dio;
  }

  static bool _canLog(RequestOptions options) =>
      !options.uri.pathSegments.any(
        (segment) =>
            segment == 'request-password-reset' ||
            segment == 'confirm-password-reset',
      ) &&
      !options.uri.queryParameters.containsKey('token');
}
