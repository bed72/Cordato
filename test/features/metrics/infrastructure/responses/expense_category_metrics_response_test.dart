import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/metrics/infrastructure/responses/expense_category_metrics_response.dart';

void main() {
  test(
    'preserves integer cents, numeric percentages and unknown categories',
    () {
      final entity = ExpenseCategoryMetricsResponse.fromJson({
        'percentage': 2.05,
        'category': 'future_category',
        'total_amount': '9007199254740993',
      }).toEntity();

      expect(entity.category, 'future_category');
      expect(entity.totalAmount, 9007199254740993);
      expect(entity.percentage, 2.05);
    },
  );

  test('accepts an integer zero percentage without calculating it', () {
    final entity = ExpenseCategoryMetricsResponse.fromJson({
      'category': 'food',
      'total_amount': '0',
      'percentage': 0,
    }).toEntity();

    expect(entity.totalAmount, 0);
    expect(entity.percentage, 0.0);
  });

  final malformed = <String, Map<String, dynamic>>{
    'fractional cents': {'total_amount': '79.65', 'percentage': 2.05},
    'numeric cents': {'total_amount': 7965, 'percentage': 2.05},
    'string percentage': {'total_amount': '7965', 'percentage': '2.05'},
    'null percentage': {'total_amount': '7965', 'percentage': null},
  };
  for (final scenario in malformed.entries) {
    test('rejects ${scenario.key}', () {
      expect(
        () => ExpenseCategoryMetricsResponse.fromJson({
          'category': 'food',
          ...scenario.value,
        }),
        throwsA(anyOf(isA<TypeError>(), isA<FormatException>())),
      );
    });
  }
}
