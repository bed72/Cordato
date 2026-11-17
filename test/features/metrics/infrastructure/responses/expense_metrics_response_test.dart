import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/metrics/infrastructure/responses/expense_metrics_response.dart';
import 'package:cordato/features/metrics/infrastructure/responses/expense_category_metrics_response.dart';

void main() {
  const record = {
    'id': 'metrics-id',
    'total_amount': '389205',
    'end_date': '2026-10-31',
    'start_date': '2026-10-01',
    'categories': [
      {'category': 'housing', 'total_amount': '216000', 'percentage': 55.5},
      {
        'category': 'future_category',
        'total_amount': '7965',
        'percentage': 2.05,
      },
    ],
  };

  group('Monthly metrics payload conversion', () {
    test('parses a flat record preserving civil dates and server values', () {
      final response = ExpenseMetricsResponse.fromJson(record);
      final entity = response.toEntity();

      expect(entity.id, 'metrics-id');
      expect(entity.totalAmount, 389205);
      expect(entity.startDate, DateTime(2026, 10));
      expect(entity.endDate, DateTime(2026, 10, 31));
      expect(entity.startDate.isUtc, isFalse);
      expect(entity.endDate.isUtc, isFalse);
      expect(entity.categories!.map((category) => category.category), [
        'housing',
        'future_category',
      ]);
      expect(entity.categories!.first.totalAmount, 216000);
      expect(entity.categories!.first.percentage, 55.5);
      expect(entity.categories!.last.totalAmount, 7965);
      expect(entity.categories!.last.percentage, 2.05);
      expect(() => response.categories!.clear(), throwsUnsupportedError);
      expect(() => entity.categories!.clear(), throwsUnsupportedError);
    });

    test('accepts zero totals with an empty grouping', () {
      final entity = ExpenseMetricsResponse.fromJson({
        ...record,
        'total_amount': '0',
        'categories': [],
      }).toEntity();

      expect(entity.totalAmount, 0);
      expect(entity.categories, isEmpty);
    });

    test('copies constructor categories before conversion', () {
      const category = ExpenseCategoryMetricsResponse(
        category: 'housing',
        totalAmount: 100,
        percentage: 100,
      );
      final categories = [category];
      final response = ExpenseMetricsResponse(
        id: 'snapshot',
        totalAmount: 100,
        startDate: DateTime(2026, 10),
        endDate: DateTime(2026, 10, 31),
        categories: categories,
      );

      categories.clear();

      expect(response.categories, [category]);
      expect(response.toEntity().categories!.single.category, 'housing');
    });
  });

  group('Malformed records', () {
    final malformed = <String, Map<String, dynamic>>{
      'old envelope': {'id': 'legacy', 'attributes': record},
      'null grouping': {...record, 'categories': null},
      'fractional amount': {...record, 'total_amount': '3892.05'},
      'numeric amount': {...record, 'total_amount': 389205},
      'invalid start': {...record, 'start_date': 'invalid'},
      'invalid end': {...record, 'end_date': 'invalid'},
      'invalid category': {
        ...record,
        'categories': [
          {'category': 'food', 'total_amount': 'invalid', 'percentage': 28.44},
        ],
      },
    };
    for (final scenario in malformed.entries) {
      test('rejects ${scenario.key} without a business fallback', () {
        expect(
          () => ExpenseMetricsResponse.fromJson(scenario.value),
          throwsA(anyOf(isA<TypeError>(), isA<FormatException>())),
        );
      });
    }
  });
}
