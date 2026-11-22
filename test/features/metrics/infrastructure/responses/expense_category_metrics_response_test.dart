import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/metrics/infrastructure/responses/expense_category_metrics_response.dart';

void main() {
  group('Local aggregate conversion', () {
    test('preserves integer cents and derives an unrounded percentage', () {
      final response = ExpenseCategoryMetricsResponse.fromJson({
        'category': 'food',
        'total_amount': 2,
      });
      final category = response.toEntity(monthlyTotal: 3);

      expect(response.category, 'food');
      expect(response.total, 2);
      expect(category.category, 'food');
      expect(category.total, 2);
      expect(category.percentage, closeTo(200 / 3, 1e-12));
    });

    final invalidGroups = <String, Map<String, dynamic>>{
      'missing category': {'total_amount': 1},
      'null category': {'category': null, 'total_amount': 1},
      'non-text category': {'category': 1, 'total_amount': 1},
      'missing sum': {'category': 'food'},
      'null sum': {'category': 'food', 'total_amount': null},
      'textual sum': {'category': 'food', 'total_amount': '123'},
      'floating sum': {'category': 'food', 'total_amount': 123.0},
      'fractional sum': {'category': 'food', 'total_amount': 1.5},
    };
    for (final scenario in invalidGroups.entries) {
      test('propagates ${scenario.key} as a parsing failure', () {
        expect(
          () => ExpenseCategoryMetricsResponse.fromJson(scenario.value),
          throwsA(isA<TypeError>()),
        );
      });
    }

    for (final amount in [0, -1]) {
      test('rejects nonpositive aggregated cents: $amount', () {
        expect(
          () => ExpenseCategoryMetricsResponse.fromJson({
            'category': 'food',
            'total_amount': amount,
          }),
          throwsFormatException,
        );
      });
    }

    test('does not turn unknown categories into other', () {
      expect(
        () => ExpenseCategoryMetricsResponse.fromJson({
          'category': 'future_category',
          'total_amount': 1,
        }),
        throwsStateError,
      );
    });
  });
}
