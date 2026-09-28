import 'dart:convert';

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

final class HttpClient({required String baseUrl, Dio? dio})
    implements IHttpClient {
  final Dio _client = dio ?? Dio();
  final Uri _baseUri = Uri.parse(baseUrl);

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
      final response = await _client.request<String>(
        _uri(parameter).toString(),
        data: parameter.body,
        options: Options(
          method: method,
          headers: parameter.headers,
          contentType: parameter.body == null ? null : Headers.jsonContentType,
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      );
      final data = _decode(response.data ?? '');

      return (response.statusCode ?? 0) >= 200 &&
              (response.statusCode ?? 0) < 300
          ? Right(data is Map<String, dynamic> ? data : {})
          : Left(data is Map<String, dynamic> ? data : _networkFailure());
    } on DioException catch (exception) {
      return Left(_networkFailure(exception.message));
    } catch (_) {
      return Left(_unknownFailure());
    }
  }

  Uri _uri(Requests parameter) {
    final uri = _baseUri.resolve(parameter.path);
    final query = parameter.query;

    if (query == null || query.isEmpty) return uri;

    final queryString = query.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value.toString())}',
        )
        .join('&');
    final separator = uri.hasQuery ? '&' : '?';

    return Uri.parse('${uri.toString()}$separator$queryString');
  }

  Object? _decode(String body) => body.trim().isEmpty ? {} : jsonDecode(body);

  Map<String, dynamic> _unknownFailure() => {
    'errors': [
      {
        'code': 'unknown',
        'message': 'Unknown error',
        'source': {'field': 'non_field_errors'},
      },
    ],
  };

  Map<String, dynamic> _networkFailure([String? message]) => {
    'errors': [
      {
        'code': 'network_error',
        'source': {'field': 'non_field_errors'},
        'message': message ?? 'Network error',
      },
    ],
  };
}
