import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/domain/value_objects/amount_value_object.dart';

final class const ExpenseResponse({
  required final String id,
  required final int amount,
  required final String description,
  required final DateTime occurredOn,
  required final ExpenseCategoryEnum category,
}) {
  factory ExpenseResponse.fromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(json['occurred_on'] as String);

    return ExpenseResponse(
      id: json['id'] as String,
      amount: json['amount'] as int,
      description: json['description'] as String? ?? '',
      occurredOn: DateTime(date.year, date.month, date.day),
      category: ExpenseCategoryEnum.values.firstWhere(
        (category) => category.value == json['category'] as String,
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
