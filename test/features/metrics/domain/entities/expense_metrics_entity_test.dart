import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';

void main() {
  group('ExpenseMetricsEntity', () {
    test('preserves the returned period and total without grouping', () {
      final startDate = DateTime(2026, 10, 1);
      final endDate = DateTime(2026, 10, 31);
      final metrics = ExpenseMetricsEntity(
        id: 'expense-metrics-id',
        startDate: startDate,
        endDate: endDate,
        totalAmount: 389205,
      );

      expect(metrics.id, 'expense-metrics-id');
      expect(metrics.startDate, same(startDate));
      expect(metrics.endDate, same(endDate));
      expect(metrics.totalAmount, 389205);
      expect(metrics.categories, isNull);
    });

    test('distinguishes empty grouped metrics from absent grouping', () {
      final metrics = ExpenseMetricsEntity(
        id: 'empty-metrics',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31),
        totalAmount: 0,
        categories: [],
      );

      expect(metrics.totalAmount, 0);
      expect(metrics.categories, isNotNull);
      expect(metrics.categories, isEmpty);
      expect(
        () => metrics.categories!.add(
          const ExpenseCategoryMetricsEntity(
            category: 'food',
            totalAmount: 100,
            percentage: 100,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('copies categories preserving their order and supplied values', () {
      const food = ExpenseCategoryMetricsEntity(
        category: 'food',
        totalAmount: 100,
        percentage: 33.33,
      );
      const housing = ExpenseCategoryMetricsEntity(
        category: 'housing',
        totalAmount: 200,
        percentage: 66.67,
      );
      final categories = [food, housing];
      final metrics = ExpenseMetricsEntity(
        id: 'grouped-metrics',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31),
        totalAmount: 300,
        categories: categories,
      );
      categories.clear();

      expect(metrics.categories, [food, housing]);
      expect(metrics.categories!.first.percentage, 33.33);
      expect(metrics.categories!.last.percentage, 66.67);
      expect(() => metrics.categories!.clear(), throwsUnsupportedError);
      expect(() => metrics.categories![0] = housing, throwsUnsupportedError);
    });
  });
}
