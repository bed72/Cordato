import 'package:tostore/tostore.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';

abstract final class ExpenseMapper {
  static ExpenseException failure(DbException exception) {
    if (exception.statuses.any((status) => status.isDeveloperError)) {
      throw exception;
    }

    return ExpenseException(
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

  static void checkQuery(QueryResult<Map<String, dynamic>> records) {
    if (records.hasErrors) {
      throw failure(
        DbException(DbResult.error(type: records.type, message: '').statuses),
      );
    }
  }

  static void checkMutation(DbResult mutation) {
    if (mutation.hasErrors) {
      throw failure(DbException(mutation.statuses));
    }
    if (mutation.successCount == 0) throw notFound();
  }

  static ExpenseException notFound() => ExpenseException(
    errors: const ErrorsEntity(
      errors: [ErrorEntity(code: 'expense_not_found')],
    ),
  );
}
