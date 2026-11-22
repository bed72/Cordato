import 'package:tostore/tostore.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/metrics/application/exceptions/metrics_exception.dart';

abstract final class MetricsMapper {
  static MetricsException failure(DbException exception) {
    if (exception.statuses.any((status) => status.isDeveloperError)) {
      throw exception;
    }

    return MetricsException(
      errors: ErrorsEntity(
        errors: exception.statuses.isEmpty
            ? ErrorsEntity.unknown().errors
            : List.unmodifiable(
                exception.statuses.map(
                  (status) => ErrorEntity(code: status.codeKey),
                ),
              ),
      ),
    );
  }

  static void checkQuery(QueryResult<Map<String, dynamic>> groups) {
    if (groups.hasErrors) {
      throw failure(
        DbException(DbResult.error(type: groups.type, message: '').statuses),
      );
    }
  }
}
