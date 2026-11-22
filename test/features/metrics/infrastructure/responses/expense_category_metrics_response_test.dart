import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/metrics/infrastructure/responses/expense_category_metrics_response.dart';

void main() {
  group('Local aggregate conversion', () {
    test('preserves integer cents and derives an unrounded percentage', () {
      const response = ExpenseCategoryMetricsResponse(
        category: 'food',
        total: 2,
      );
      final category = response.toEntity(monthlyTotal: 3);

      expect(response.category, 'food');
      expect(response.total, 2);
      expect(category.category, 'food');
      expect(category.total, 2);
      expect(category.percentage, closeTo(200 / 3, 1e-12));
    });
  });
}
