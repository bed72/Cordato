import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';

sealed class ExpenseEvent {
  const ExpenseEvent();
}

final class const ExpenseRequestedEvent({required final String? id})
    extends ExpenseEvent {}

final class const ExpenseSubmittedEvent({
  final String? id,
  final int? cents,
  final String? description,
  final DateTime? occurredOn,
  final ExpenseCategoryEnum? category,
  final bool keepFormOpen = false,
}) extends ExpenseEvent {}
