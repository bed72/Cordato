import 'package:dio/dio.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';

abstract final class ResponseMapper {
  static ErrorsEntity fromException(DioException exception) {
    switch (exception.error) {
      case final Error error:
        throw error;
      case final FormatException error:
        throw error;
    }

    final response = exception.response;
    if (response == null) return .unknown();

    final body = response.data;
    final code = body is Map<String, dynamic> ? body['type'] as String? : null;

    return ErrorsEntity(
      errors: [
        ErrorEntity(status: response.statusCode?.toString(), code: code),
      ],
    );
  }
}
