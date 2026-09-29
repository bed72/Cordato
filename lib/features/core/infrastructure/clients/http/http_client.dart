import 'package:dio/dio.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

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
          contentType: parameter.body == null
              ? null
              : parameter.headers?['Content-Type'] as String? ??
                    Headers.jsonContentType,
        ),
      );
      final data = response.data;
      final statusCode = response.statusCode ?? 0;
      final isSuccess = statusCode >= 200 && statusCode < 300;

      if (data == null && isSuccess) return const Right({});
      if (data is! Map<String, dynamic>) return Left(_unknownFailure());

      return isSuccess ? Right(data) : Left(data);
    } on DioException catch (_) {
      return Left(_unknownFailure());
    } catch (_) {
      return Left(_unknownFailure());
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
