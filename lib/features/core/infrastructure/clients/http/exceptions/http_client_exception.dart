import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_exception_enum.dart';

sealed class HttpClientException implements Exception {}

final class HttpUnexpectedException extends HttpClientException {}

final class HttpInvalidResponseException({required final int? status})
    extends HttpClientException {}

final class HttpResponseException({required final Responses response})
    extends HttpClientException {}

final class HttpTransportException({required final HttpExceptionEnum failure})
    extends HttpClientException {}
