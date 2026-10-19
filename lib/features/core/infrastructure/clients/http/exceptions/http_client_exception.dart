import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_exception_enum.dart';

sealed class HttpClientException implements Exception {}

final class HttpUnexpectedException extends HttpClientException {}

final class HttpTransportException({required final HttpExceptionEnum failure})
    extends HttpClientException {}

final class HttpInvalidResponseException({required final int? status})
    extends HttpClientException {}

final class HttpResponseException({
  required final int status,
  required final ErrorsResponse errors,
}) extends HttpClientException {
  factory HttpResponseException.fromResponse(Responses response) {
    ErrorsResponse errors;
    try {
      errors = .fromJson(response.body);
    } on TypeError {
      errors = .unknown();
    } on FormatException {
      errors = .unknown();
    }

    return HttpResponseException(status: response.status, errors: errors);
  }
}
