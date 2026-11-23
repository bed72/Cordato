import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/enums/category_enum.dart';
import 'package:cordato/features/expense/domain/value_objects/amount_value_object.dart';

final class const ExpenseResponse({
  required final int id,
  required final int amount,
  required final String description,
  required final DateTime occurredOn,
  required final CategoryEnum category,
}) {
  factory ExpenseResponse.fromRecord(ExpensesTableData record) {
    final date = DateTime.parse(record.occurredOn);

    return ExpenseResponse(
      id: record.id,
      amount: record.amount,
      description: record.description ?? '',
      occurredOn: DateTime(date.year, date.month, date.day),
      category: CategoryEnum.values.firstWhere(
        (category) => category.value == record.category,
      ),
    );
  }
}

extension ExpenseResponseToEntity on ExpenseResponse {
  ExpenseEntity toEntity() => ExpenseEntity(
    id: id,
    category: category,
    occurredOn: occurredOn,
    description: description,
    cents: AmountValueObject.create(cents: amount),
  );
}
