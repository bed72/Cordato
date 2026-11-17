import 'package:dio/dio.dart';

import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_method_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';

abstract interface class IHttpClient {
  void close({bool force = false});
  Future<Responses> get({required Requests parameter});
  Future<Responses> put({required Requests parameter});
  Future<Responses> post({required Requests parameter});
  Future<Responses> patch({required Requests parameter});
  Future<Responses> delete({required Requests parameter});
}

final class HttpClient({required final Dio _dio}) implements IHttpClient {
  @override
  void close({bool force = false}) => _dio.close(force: force);

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
          method: method.value,
          headers: parameter.headers,
          validateStatus: (_) => true,
        ),
      );
      final status = response.statusCode;
      if (status == null) throw HttpInvalidResponseException(status: null);

      final body = response.data;
      if (status < 200 || status >= 300) {
        throw HttpResponseException(
          response: Responses(
            status: status,
            body: body is Map<String, dynamic> ? body : const {},
          ),
        );
      }

      return Responses(
        status: status,
        body: switch (body) {
          null || '' => const {},
          Map<String, dynamic> data => data,
          _ => throw HttpInvalidResponseException(status: status),
        },
      );
    } on DioException catch (exception) {
      switch (exception.error) {
        case final Error error:
          Error.throwWithStackTrace(error, exception.stackTrace);
        case final FormatException error:
          Error.throwWithStackTrace(error, exception.stackTrace);
      }

      throw switch (exception.type) {
        .badResponse || .unknown => HttpUnexpectedException(),
        .cancel => HttpTransportException(failure: .cancelled),
        .badCertificate ||
        .connectionError => HttpTransportException(failure: .connection),
        .sendTimeout ||
        .receiveTimeout ||
        .transformTimeout ||
        .connectionTimeout => HttpTransportException(failure: .timeout),
      };
    }
  }
}
