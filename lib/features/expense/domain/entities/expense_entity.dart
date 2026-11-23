import 'package:cordato/features/expense/domain/enums/category_enum.dart';
import 'package:cordato/features/expense/domain/value_objects/amount_value_object.dart';

final class const ExpenseEntity({
  required final int id,
  required final String description,
  required final DateTime occurredOn,
  required final AmountValueObject cents,
  required final CategoryEnum category,
});
