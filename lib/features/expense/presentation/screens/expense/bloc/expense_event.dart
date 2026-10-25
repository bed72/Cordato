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
  final bool keepFormOpen = false,
}) extends ExpenseEvent {}
