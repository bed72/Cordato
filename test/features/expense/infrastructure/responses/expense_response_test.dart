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
            'occurred_on': '2026-10-05',
            'description': 'Game',
            'category': 'other',
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
      test('recognizes the API category ${category.name}', () {
        final response = ExpenseResponse.fromJson({
          'data': {
            'id': '9',
            'attributes': {
              'amount': 300,
              'occurred_on': '2026-10-05',
              'description': 'Game',
              'category': category.name,
            },
          },
        });

        expect(response.category, category);
        expect(response.toEntity().right.category, category);
      });
    }

    for (final amount in [0, -300]) {
      test('returns a domain error for $amount cents during conversion', () {
        final response = ExpenseResponse(
          id: '9',
          amount: amount,
          description: 'Game',
          occurredOn: DateTime(2026, 10, 5),
          category: .other,
        );

        final result = response.toEntity();

        expect(result.isLeft, isTrue);
        expect(result.left.errors.single.title, 'Valor inválido');
      });
    }
  });
}
