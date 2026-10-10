import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';

final class ExpenseMetricsEntity({
  required final String id,
  required final int totalAmount,
  required final DateTime endDate,
  required final DateTime startDate,
  List<ExpenseCategoryMetricsEntity>? categories,
}) {
  final List<ExpenseCategoryMetricsEntity>? categories = categories == null
      ? null
      : .unmodifiable(categories);
}
