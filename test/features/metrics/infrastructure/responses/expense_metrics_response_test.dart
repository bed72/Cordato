import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/metrics/infrastructure/responses/expense_category_metrics_response.dart';
import 'package:cordato/features/metrics/infrastructure/responses/expense_metrics_response.dart';

void main() {
  late Map<String, dynamic> attributes;

  setUp(() {
    attributes = {
      'total_amount': '389205',
      'start_date': '2026-10-01',
      'end_date': '2026-10-31',
    };
  });

  group('Metrics conversion and optional grouping', () {
    test(
      'parses a JSON:API resource preserving integer cents and civil dates',
      () {
        final response = ExpenseMetricsResponse.fromJson({
          'id': 'metrics-id',
          'type': 'expense-metrics',
          'attributes': attributes,
        });
        final entity = response.toEntity();

        expect(entity.id, 'metrics-id');
        expect(entity.totalAmount, 389205);
        expect(entity.startDate, DateTime(2026, 10, 1));
        expect(entity.endDate, DateTime(2026, 10, 31));
        expect(entity.startDate.isUtc, isFalse);
        expect(entity.endDate.isUtc, isFalse);
        expect(entity.categories, isNull);
      },
    );

    test('preserves explicit null grouping and zero totals', () {
      attributes['total_amount'] = '0';
      attributes['categories'] = null;
      final entity = ExpenseMetricsResponse.fromJson({
        'id': 'empty',
        'attributes': attributes,
      }).toEntity();

      expect(entity.totalAmount, 0);
      expect(entity.categories, isNull);
    });

    test('distinguishes an empty grouping from an absent grouping', () {
      attributes['categories'] = [];
      final response = ExpenseMetricsResponse.fromJson({
        'id': 'grouped',
        'attributes': attributes,
      });

      expect(response.categories, isNotNull);
      expect(response.toEntity().categories, isEmpty);
    });

    test(
      'converts grouped metrics preserving category order and percentages',
      () {
        attributes['categories'] = [
          {
            'category': 'housing',
            'total_amount': '216000',
            'percentage': '55.50',
          },
          {
            'category': 'future_category',
            'total_amount': '7965',
            'percentage': '2.05',
          },
        ];
        final response = ExpenseMetricsResponse.fromJson({
          'id': 'grouped',
          'attributes': attributes,
        });
        final entity = response.toEntity();

        expect(entity.categories!.map((category) => category.category), [
          'housing',
          'future_category',
        ]);
        expect(entity.categories!.first.totalAmount, 216000);
        expect(entity.categories!.first.percentage, 55.50);
        expect(entity.categories!.last.totalAmount, 7965);
        expect(entity.categories!.last.percentage, 2.05);
        expect(() => response.categories!.clear(), throwsUnsupportedError);
        expect(() => entity.categories!.clear(), throwsUnsupportedError);
      },
    );
  });

  group('Immutability and malformed responses', () {
    test('copies the supplied category list before conversion', () {
      const category = ExpenseCategoryMetricsResponse(
        category: 'housing',
        totalAmount: 100,
        percentage: 100,
      );
      final categories = [category];
      final response = ExpenseMetricsResponse(
        id: 'snapshot',
        totalAmount: 100,
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31),
        categories: categories,
      );
      categories.clear();

      expect(response.categories, [category]);
      expect(response.toEntity().categories!.single.category, 'housing');
    });

    test('rejects malformed amounts and dates', () {
      for (final invalid in [
        {'total_amount': '3892.05'},
        {'start_date': 'invalid'},
        {'end_date': 'invalid'},
      ]) {
        expect(
          () => ExpenseMetricsResponse.fromJson({
            'id': 'invalid',
            'attributes': {...attributes, ...invalid},
          }),
          throwsFormatException,
        );
      }
    });

    test('rejects the entire response when one category cannot be parsed', () {
      attributes['categories'] = [
        {
          'category': 'housing',
          'total_amount': '216000',
          'percentage': '55.50',
        },
        {'category': 'food', 'total_amount': 'invalid', 'percentage': '28.44'},
      ];

      expect(
        () => ExpenseMetricsResponse.fromJson({
          'id': 'invalid-category',
          'attributes': attributes,
        }),
        throwsFormatException,
      );
    });
  });
}
