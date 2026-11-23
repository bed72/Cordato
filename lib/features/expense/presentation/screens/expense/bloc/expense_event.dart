import 'package:cordato/features/expense/domain/enums/category_enum.dart';

sealed class ExpenseEvent {
  const ExpenseEvent();
}

final class const ExpenseRequestedEvent({required final int? id})
    extends ExpenseEvent {}

final class const ExpenseSubmittedEvent({
  final int? id,
  final int? cents,
  final String? description,
  final DateTime? occurredOn,
  final CategoryEnum? category,
  final bool keepFormOpen = false,
}) extends ExpenseEvent {}
