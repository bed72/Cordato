import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/infrastructure/responses/expense_category_metrics_response.dart';

final class ExpenseMetricsResponse({
  required final String id,
  required final int totalAmount,
  required final DateTime endDate,
  required final DateTime startDate,
  List<ExpenseCategoryMetricsResponse>? categories,
}) {
  final List<ExpenseCategoryMetricsResponse>? categories = categories == null
      ? null
      : .unmodifiable(categories);

  factory ExpenseMetricsResponse.fromJson(Map<String, dynamic> json) {
    final categories = json['categories'] as List<dynamic>;

    return ExpenseMetricsResponse(
      id: json['id'] as String,
      endDate: DateTime.parse(json['end_date'] as String),
      totalAmount: int.parse(json['total_amount'] as String),
      startDate: DateTime.parse(json['start_date'] as String),
      categories: categories
          .map(
            (category) => ExpenseCategoryMetricsResponse.fromJson(
              category as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

extension ExpenseMetricsResponseToEntity on ExpenseMetricsResponse {
  ExpenseMetricsEntity toEntity() => ExpenseMetricsEntity(
    id: id,
    endDate: endDate,
    startDate: startDate,
    totalAmount: totalAmount,
    categories: categories?.map((category) => category.toEntity()).toList(),
  );
}
