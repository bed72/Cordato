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
    final data = json['data'] as Map<String, dynamic>;
    final attributes = data['attributes'] as Map<String, dynamic>;

    return ExpenseResponse(
      id: data['id'] as String,
      amount: attributes['amount'] as int,
      description: attributes['description'] as String,
      occurredOn: DateTime.parse(attributes['occurred_on'] as String),
      category: ExpenseCategoryEnum.values.firstWhere(
        (category) => category.value == attributes['category'] as String,
      ),
    );
  }
}

extension ExpenseResponseToEntity on ExpenseResponse {
  ExpenseEntity toEntity() => ExpenseEntity(
    id: id,
    cents: AmountValueObject.create(cents: amount),
    category: category,
    occurredOn: occurredOn,
    description: description,
  );
}
