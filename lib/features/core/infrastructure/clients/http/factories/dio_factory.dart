import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

import 'package:cordato/features/core/infrastructure/clients/logger/logger_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_extra_key_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/interceptors/headers_interceptor.dart';
import 'package:cordato/features/core/infrastructure/clients/http/interceptors/opaque_token_interceptor.dart';

final class DioFactory {
  const DioFactory._();

  static Dio create({
    required String baseUrl,
    required IStorageClient storage,
  }) {
    final dio = Dio(BaseOptions(baseUrl: baseUrl));

    dio.interceptors.addAll([
      HeadersInterceptor(),
      OpaqueTokenInterceptor(storage: storage),
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
            requestFilter: (options) =>
                options.extra[HttpExtraKeyEnum.skipLogging.key] != true,
            responseFilter: (response) =>
                response.requestOptions.extra[HttpExtraKeyEnum
                    .skipLogging
                    .key] !=
                true,
            errorFilter: (error) =>
                error.requestOptions.extra[HttpExtraKeyEnum.skipLogging.key] !=
                true,
          ),
        ),
    ]);

    return dio;
  }
}
