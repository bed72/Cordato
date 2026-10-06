import 'package:cordato/features/expense/domain/entities/expense_entity.dart';

final class ExpensePageEntity({
  required final String? next,
  required final String? prev,
  required List<ExpenseEntity> items,
}) {
  final List<ExpenseEntity> items = .unmodifiable(items);
}
