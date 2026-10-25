import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';

sealed class ExpenseMetricsState {
  const ExpenseMetricsState();

  bool get isLoading => this is ExpenseMetricsLoading;

  ExpenseMetricsEntity? get metrics => switch (this) {
    ExpenseMetricsSuccess(:final data) => data,
    _ => null,
  };
}

final class const ExpenseMetricsInitial() extends ExpenseMetricsState {}

final class const ExpenseMetricsLoading() extends ExpenseMetricsState {}

final class const ExpenseMetricsSuccess({
  required final ExpenseMetricsEntity data,
}) extends ExpenseMetricsState {}

final class const ExpenseMetricsFailure({required final ErrorsEntity errors})
    extends ExpenseMetricsState {}
