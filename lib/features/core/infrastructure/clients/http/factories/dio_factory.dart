import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

import 'package:cordato/features/core/infrastructure/clients/logger/logger_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/interceptors/headers_interceptor.dart';

final class DioFactory {
  const DioFactory._();

  static Dio create({required String baseUrl}) {
    final dio = Dio(BaseOptions(baseUrl: baseUrl));

    dio.interceptors.addAll([
      HeadersInterceptor(),
      if (kDebugMode)
        TalkerDioLogger(
          talker: loggerClient,
          settings: const TalkerDioLoggerSettings(
            printRequestHeaders: kDebugMode,
            printResponseMessage: kDebugMode,
            printResponseHeaders: kDebugMode,
          ),
        ),
    ]);

    return dio;
  }
}
