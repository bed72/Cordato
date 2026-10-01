import 'package:dio/dio.dart';

abstract interface class IEmailVerificationClient {
  Future<int?> confirm(String url);
}

// Isolated from the shared Dio instance: no auth headers, URL logger or redirects.
final class EmailVerificationClient({Dio? dio})
    implements IEmailVerificationClient {
  final Dio _dio = dio ?? Dio();

  @override
  Future<int?> confirm(String url) async {
    try {
      final response = await _dio.get<void>(
        url,
        options: Options(
          followRedirects: false,
          validateStatus: (_) => true,
          responseType: ResponseType.plain,
        ),
      );
      return response.statusCode;
    } on DioException catch (_) {
      return null;
    }
  }
}
