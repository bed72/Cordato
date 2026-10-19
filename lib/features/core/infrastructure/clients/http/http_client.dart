import 'package:dio/dio.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_method_enum.dart';

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
      _execute(HttpMethodEnum.get, parameter);

  @override
  Future<Responses> put({required Requests parameter}) =>
      _execute(HttpMethodEnum.put, parameter);

  @override
  Future<Responses> post({required Requests parameter}) =>
      _execute(HttpMethodEnum.post, parameter);

  @override
  Future<Responses> patch({required Requests parameter}) =>
      _execute(HttpMethodEnum.patch, parameter);

  @override
  Future<Responses> delete({required Requests parameter}) =>
      _execute(HttpMethodEnum.delete, parameter);

  Future<Responses> _execute(HttpMethodEnum method, Requests parameter) async {
    try {
      final response = await _dio.request<dynamic>(
        parameter.path,
        data: parameter.body,
        queryParameters: parameter.query,
        options: Options(
          responseType: .json,
          method: method.value,
          headers: parameter.headers,
          validateStatus: (_) => true,
          contentType: parameter.body == null
              ? null
              : parameter.headers?['Content-Type'] as String? ??
                    Headers.jsonContentType,
        ),
      );

      final data = response.data;
      final status = response.statusCode ?? 0;
      final isSuccess = status >= 200 && status < 300;
      final body = data == null || data == '' ? <String, dynamic>{} : data;

      if (body is! Map<String, dynamic>) {
        return Left(Reponse(status: status, body: _unknown));
      }

      final value = Reponse(status: status, body: body);

      return isSuccess ? Right(value) : Left(value);
    } on DioException catch (_) {
      return Left(Reponse(status: 500, body: _unknown));
    } catch (_) {
      return Left(Reponse(status: 500, body: _unknown));
    }
  }

  Map<String, dynamic> get _unknown => {
    'errors': [
      {
        'title': 'Erro desconhecido',
        'detail': 'Não foi possível processar a resposta.',
      },
    ],
  };
}
