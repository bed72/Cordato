import 'package:dio/dio.dart';

import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_method_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';

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

      final status = response.statusCode;
      if (status == null) throw HttpInvalidResponseException(status: null);

      final isSuccess = status >= 200 && status < 300;
      final body = switch (response.data) {
        null || '' => <String, dynamic>{},
        Map<String, dynamic> data => data,
        _ => throw HttpInvalidResponseException(status: status),
      };

      final data = Responses(status: status, body: body);
      if (!isSuccess) throw HttpResponseException.fromResponse(data);

      return data;
    } on DioException catch (error) {
      throw switch (error.type) {
        .badResponse || .unknown => HttpUnexpectedException(),
        .cancel => HttpTransportException(failure: .cancelled),
        .connectionError ||
        .badCertificate => HttpTransportException(failure: .connection),
        .sendTimeout ||
        .receiveTimeout ||
        .connectionTimeout ||
        .transformTimeout => HttpTransportException(failure: .timeout),
      };
    }
  }
}
