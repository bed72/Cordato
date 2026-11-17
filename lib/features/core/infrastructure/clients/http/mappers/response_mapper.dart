import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';

abstract final class ResponseMapper {
  static ErrorsEntity fromException(HttpClientException exception) =>
      switch (exception) {
        HttpResponseException(:final response) => ErrorsEntity(
          errors: [
            ErrorEntity(
              status: response.status.toString(),
              code: response.body['type'] as String?,
            ),
          ],
        ),
        HttpInvalidResponseException() => throw const FormatException(
          'Resposta HTTP inválida',
        ),
        HttpTransportException() || HttpUnexpectedException() => .unknown(),
      };
}
