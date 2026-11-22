import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';

final class const ExpenseCategoryMetricsResponse({
  required final int total,
  required final String category,
}) {
  factory ExpenseCategoryMetricsResponse.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as String;
    ExpenseCategoryEnum.values.firstWhere((item) => item.value == category);

    final amount = json['total_amount'] as int;
    if (amount <= 0) throw const FormatException('Invalid expense aggregation');

    return ExpenseCategoryMetricsResponse(category: category, total: amount);
  }

  ExpenseCategoryMetricsEntity toEntity({required int monthlyTotal}) =>
      ExpenseCategoryMetricsEntity(
        total: total,
        category: category,
        percentage: total / monthlyTotal * 100,
      );
}
