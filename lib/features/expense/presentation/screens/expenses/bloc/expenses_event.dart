import 'package:cordato/features/expense/domain/entities/expense_entity.dart';

sealed class ExpensesEvent {
  const ExpensesEvent();
}

final class const ExpensesRequestedEvent({
  final DateTime? to,
  final DateTime? from,
  final String? category,
}) extends ExpensesEvent {}

final class const ExpensesNextPageRequestedEvent() extends ExpensesEvent {}

final class const ExpensesDeleteRequestedEvent({required final int id})
    extends ExpensesEvent {}

final class const ExpensesUpdatedEvent({required final ExpenseEntity expense})
    extends ExpensesEvent {}

final class ExpensesReregisterRequestedEvent({
  required final ExpenseEntity expense,
  required DateTime confirmedAt,
}) extends ExpensesEvent {
  final DateTime occurredOn;

  this
    : occurredOn = DateTime.utc(
        confirmedAt.year,
        confirmedAt.month,
        confirmedAt.day,
      );
}
