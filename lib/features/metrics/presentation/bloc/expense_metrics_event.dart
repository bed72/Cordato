import 'package:cordato/features/metrics/domain/enums/expense_metrics_group_by_enum.dart';

sealed class ExpenseMetricsEvent {
  const ExpenseMetricsEvent();
}

final class const ExpenseMetricsRequestedEvent({
  final DateTime? endDate,
  final DateTime? startDate,
  final ExpenseMetricsGroupByEnum? groupBy,
}) extends ExpenseMetricsEvent {}
