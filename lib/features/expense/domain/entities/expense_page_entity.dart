import 'package:cordato/features/expense/domain/entities/expense_entity.dart';

final class ExpensePageEntity({
  required final int? nextPage,
  required List<ExpenseEntity> items,
}) {
  final List<ExpenseEntity> items = .unmodifiable(items);
}
