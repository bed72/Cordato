import 'package:cordato/features/expense/domain/entities/expense_entity.dart';

sealed class ExpensesEvent {
  const ExpensesEvent();
}

final class const ExpensesRequestedEvent({
  final String? category,
  final DateTime? from,
  final DateTime? to,
}) extends ExpensesEvent {}

final class const ExpensesNextPageRequestedEvent() extends ExpensesEvent {}

final class const ExpensesDeleteRequestedEvent({required final String id})
    extends ExpensesEvent {}

final class const ExpensesUpdatedEvent({required final ExpenseEntity expense})
    extends ExpensesEvent {}
