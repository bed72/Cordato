import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';

final class const ExpenseCategoryMetricsResponse({
  required final int total,
  required final String category,
}) {
  ExpenseCategoryMetricsEntity toEntity({required int monthlyTotal}) =>
      ExpenseCategoryMetricsEntity(
        total: total,
        category: category,
        percentage: total / monthlyTotal * 100,
      );
}
