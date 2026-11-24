import 'package:drift/drift.dart';

import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';
import 'package:cordato/features/core/infrastructure/clients/database/database_operation.dart';

import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_export_repository.dart';

import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';
import 'package:cordato/features/expense/infrastructure/serializers/expense_csv_serializer.dart';

final class ExpenseExportRepository({required final DatabaseClient _client})
    implements IExpenseExportRepository {
  @override
  Future<Uint8List?> prepare() => runDatabaseOperation(
    operation: () async {
      final query = _client.select(_client.expensesTable)
        ..where(
          (row) => row.profileId.equalsExp(
            subqueryExpression<int>(
              _client.selectOnly(_client.profilesTable)
                ..addColumns([_client.profilesTable.id]),
            ),
          ),
        )
        ..orderBy([(row) => .asc(row.occurredOn), (row) => .asc(row.id)]);
      final records = await query.get();
      if (records.isEmpty) return null;

      return const ExpenseCsvSerializer().encode(
        expenses: records.map(
          (record) => ExpenseResponse.fromRecord(record).toEntity(),
        ),
      );
    },
    onFailure: () => ExpenseException(errors: .unknown()),
  );
}
