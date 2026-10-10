import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/metrics/infrastructure/responses/expense_category_metrics_response.dart';

void main() {
  test('parses numeric strings and preserves unknown category values', () {
    final response = ExpenseCategoryMetricsResponse.fromJson({
      'category': 'future_category',
      'total_amount': '7965',
      'percentage': '2.05',
    });
    final entity = response.toEntity();

    expect(entity.category, 'future_category');
    expect(entity.totalAmount, 7965);
    expect(entity.percentage, 2.05);
  });

  test('converts a category with no expenses', () {
    final entity = ExpenseCategoryMetricsResponse.fromJson({
      'category': 'food',
      'total_amount': '0',
      'percentage': '0.00',
    }).toEntity();

    expect(entity.totalAmount, 0);
    expect(entity.percentage, 0);
  });

  test('rejects fractional monetary amounts and malformed percentages', () {
    for (final attributes in [
      {'total_amount': '79.65', 'percentage': '2.05'},
      {'total_amount': '7965', 'percentage': 'invalid'},
    ]) {
      expect(
        () => ExpenseCategoryMetricsResponse.fromJson({
          'category': 'food',
          ...attributes,
        }),
        throwsFormatException,
      );
    }
  });
}
