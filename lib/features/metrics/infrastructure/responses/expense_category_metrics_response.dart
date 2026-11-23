import 'package:cordato/features/metrics/infrastructure/daos/metrics_dao.dart';
import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';

final class const ExpenseCategoryMetricsResponse({
  required final int total,
  required final String category,
}) {
  factory ExpenseCategoryMetricsResponse.fromRecord(
    ExpenseCategoryMetricsRecord record,
  ) => ExpenseCategoryMetricsResponse(
    total: record.total,
    category: record.category,
  );

  ExpenseCategoryMetricsEntity toEntity({required int monthlyTotal}) =>
      ExpenseCategoryMetricsEntity(
        total: total,
        category: category,
        percentage: total / monthlyTotal * 100,
      );
}
