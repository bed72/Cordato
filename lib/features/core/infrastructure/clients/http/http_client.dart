import 'package:dio/dio.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_extra_key_enum.dart';

abstract interface class IHttpClient {
  Future<Responses> get({required Requests parameter});
  Future<Responses> put({required Requests parameter});
  Future<Responses> post({required Requests parameter});
  Future<Responses> patch({required Requests parameter});
  Future<Responses> delete({required Requests parameter});
}

final class HttpClient({required final Dio _dio}) implements IHttpClient {
  @override
  Future<Responses> get({required Requests parameter}) =>
      _execute('GET', parameter);

  @override
  Future<Responses> post({required Requests parameter}) =>
      _execute('POST', parameter);

  @override
  Future<Responses> put({required Requests parameter}) =>
      _execute('PUT', parameter);

  @override
  Future<Responses> patch({required Requests parameter}) =>
      _execute('PATCH', parameter);

  @override
  Future<Responses> delete({required Requests parameter}) =>
      _execute('DELETE', parameter);

  Future<Responses> _execute(String method, Requests parameter) async {
    try {
      final response = await _dio.request<dynamic>(
        parameter.path,
        data: parameter.body,
        queryParameters: parameter.query,
        options: Options(
          method: method,
          responseType: .json,
          headers: parameter.headers,
          validateStatus: (_) => true,
          followRedirects: parameter.followRedirects,
          extra: {
            HttpExtraKeyEnum.route.key: parameter.route,
            HttpExtraKeyEnum.skipLogging.key: !parameter.logRequest,
          },
          contentType: parameter.body == null
              ? null
              : parameter.headers?['Content-Type'] as String? ??
                    Headers.jsonContentType,
        ),
      );

      final data = response.data;
      final statusCode = response.statusCode ?? 0;
      final isSuccess = statusCode >= 200 && statusCode < 300;
      final body = data == null || data == '' ? <String, dynamic>{} : data;

      if (body is! Map<String, dynamic>) {
        return Left(
          HttpResponse(statusCode: statusCode, body: _unknownFailure()),
        );
      }

      final value = HttpResponse(statusCode: statusCode, body: body);
      return isSuccess ? Right(value) : Left(value);
    } on DioException catch (_) {
      return Left(HttpResponse(statusCode: 0, body: _unknownFailure()));
    } catch (_) {
      return Left(HttpResponse(statusCode: 0, body: _unknownFailure()));
    }
  }

  Map<String, dynamic> _unknownFailure() => {
    'errors': [
      {
        'title': 'Erro desconhecido',
        'detail': 'Não foi possível processar a resposta.',
      },
    ],
  };
}
