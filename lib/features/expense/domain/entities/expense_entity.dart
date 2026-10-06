import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/domain/value_objects/amount_value_object.dart';

final class const ExpenseEntity({
  required final String id,
  required final String description,
  required final DateTime occurredOn,
  required final AmountValueObject cents,
  required final ExpenseCategoryEnum category,
});
