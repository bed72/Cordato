import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';

extension ExpenseMetricsCategoriesExtension
    on List<ExpenseCategoryMetricsEntity> {
  List<List<ExpenseCategoryMetricsEntity>> get cardPages {
    final visible = indexed.where((entry) => entry.$2.totalAmount > 0).toList()
      ..sort((a, b) {
        final amountOrder = b.$2.totalAmount.compareTo(a.$2.totalAmount);
        return amountOrder == 0 ? a.$1.compareTo(b.$1) : amountOrder;
      });
    return [
      for (int start = 0; start < visible.length; start += 3)
        [for (final entry in visible.skip(start).take(3)) entry.$2],
    ];
  }
}
