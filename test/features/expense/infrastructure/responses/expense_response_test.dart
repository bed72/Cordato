import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';

void main() {
  group('ExpenseResponse', () {
    test('maps a JSON:API expense into a validated domain entity', () {
      final response = ExpenseResponse.fromJson({
        'data': {
          'id': '9',
          'type': 'expenses',
          'attributes': {
            'amount': 300,
            'category': 'other',
            'description': 'Game',
            'occurred_on': '2026-10-05',
            'created_at': '2026-10-06T19:24:29+00:00',
          },
        },
      });

      expect(response.amount, 300);
      final entity = response.toEntity().right;

      expect(entity.id, '9');
      expect(entity.cents.cents, 300);
      expect(entity.description, 'Game');
      expect(entity.occurredOn, DateTime(2026, 10, 5));
      expect(entity.category, ExpenseCategoryEnum.other);
    });

    for (final category in ExpenseCategoryEnum.values) {
      test('recognizes the API category ${category.value}', () {
        final response = ExpenseResponse.fromJson({
          'data': {
            'id': '9',
            'attributes': {
              'amount': 300,
              'description': 'Game',
              'occurred_on': '2026-10-05',
              'category': category.value,
            },
          },
        });

        expect(response.category, category);
        expect(response.toEntity().right.category, category);
      });
    }

    test('rejects categories outside the API contract', () {
      expect(
        () => ExpenseResponse.fromJson({
          'data': {
            'id': '9',
            'attributes': {
              'amount': 300,
              'description': 'Game',
              'category': 'unknown',
              'occurred_on': '2026-10-05',
            },
          },
        }),
        throwsStateError,
      );
    });

    for (final amount in [0, -300]) {
      test('returns a domain error for $amount cents during conversion', () {
        final response = ExpenseResponse(
          id: '9',
          amount: amount,
          category: .other,
          description: 'Game',
          occurredOn: DateTime(2026, 10, 5),
        );

        final data = response.toEntity();

        expect(data.isLeft, isTrue);
        expect(data.left.errors.single.title, 'Valor inválido');
      });
    }
  });
}
