import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import 'package:cordato/features/core/infrastructure/clients/http/interceptors/origin_interceptor.dart';

abstract final class HttpClient {
  static Dio create({
    required String endpoint,
    required String projectId,
    required PersistCookieJar cookies,
  }) {
    final client = Dio(
      BaseOptions(
        baseUrl: endpoint,
        followRedirects: false,
        contentType: Headers.jsonContentType,
        sendTimeout: const Duration(seconds: 20),
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'X-Appwrite-Project': projectId,
          'Accept': Headers.jsonContentType,
        },
      ),
    );

    client.interceptors.addAll([
      OriginInterceptor(origin: .parse(endpoint)),
      CookieManager(cookies),
    ]);

    return client;
  }
}
