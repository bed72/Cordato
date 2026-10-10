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
    final attributes = json['attributes'] as Map<String, dynamic>;
    final categories = attributes['categories'] as List<dynamic>?;

    return ExpenseMetricsResponse(
      id: json['id'] as String,
      totalAmount: int.parse(attributes['total_amount'] as String),
      endDate: DateTime.parse(attributes['end_date'] as String),
      startDate: DateTime.parse(attributes['start_date'] as String),
      categories: categories
          ?.map(
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
