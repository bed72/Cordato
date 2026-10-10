import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';

final class const ExpenseCategoryMetricsResponse({
  required final String category,
  required final int totalAmount,
  required final double percentage,
}) {
  factory ExpenseCategoryMetricsResponse.fromJson(Map<String, dynamic> json) =>
      ExpenseCategoryMetricsResponse(
        category: json['category'] as String,
        totalAmount: int.parse(json['total_amount'] as String),
        percentage: double.parse(json['percentage'] as String),
      );
}

extension ExpenseCategoryMetricsResponseToEntity
    on ExpenseCategoryMetricsResponse {
  ExpenseCategoryMetricsEntity toEntity() => ExpenseCategoryMetricsEntity(
    category: category,
    percentage: percentage,
    totalAmount: totalAmount,
  );
}
