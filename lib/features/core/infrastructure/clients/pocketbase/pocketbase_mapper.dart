import 'package:pocketbase/pocketbase.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';

abstract final class PocketBaseMapper {
  static ErrorsEntity fromException(ClientException exception) {
    switch (exception.originalError) {
      case final Error error:
        throw error;
      case final FormatException error:
        throw error;
    }

    if (exception.statusCode <= 0) return .unknown();

    final status = exception.statusCode.toString();
    final message = exception.response['message'] as String?;
    final data = exception.response['data'] as Map<String, dynamic>?;

    if (data == null || data.isEmpty) {
      return ErrorsEntity(
        errors: [ErrorEntity(status: status, detail: message)],
      );
    }

    return ErrorsEntity(
      errors: data.entries.map((entry) {
        final fieldError = entry.value as Map<String, dynamic>;
        final field = entry.key.replaceAll('~', '~0').replaceAll('/', '~1');

        return ErrorEntity(
          title: message,
          status: status,
          pointer: '/$field',
          parameter: entry.key,
          code: fieldError['code'] as String?,
          detail: fieldError['message'] as String?,
        );
      }).toList(),
    );
  }
}
