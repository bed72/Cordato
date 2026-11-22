import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';

void main() {
  group('ExpenseCategoryMetricsEntity', () {
    test('preserves integer cents and the supplied percentage', () {
      const category = ExpenseCategoryMetricsEntity(
        category: 'housing',
        percentage: 55.50,
        total: 216000,
      );

      expect(category.percentage, 55.50);
      expect(category.category, 'housing');
      expect(category.total, 216000);
    });

    test('preserves unknown categories without substituting other', () {
      const category = ExpenseCategoryMetricsEntity(
        total: 7965,
        percentage: 2.05,
        category: 'future_category',
      );

      expect(category.percentage, 2.05);
      expect(category.total, 7965);
      expect(category.category, 'future_category');
    });

    test('represents a category with no expenses', () {
      const category = ExpenseCategoryMetricsEntity(
        percentage: 0,
        total: 0,
        category: 'food',
      );

      expect(category.percentage, 0);
      expect(category.total, 0);
    });
  });
}
