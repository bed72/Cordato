import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';

void main() {
  group('ExpenseResponse', () {
    test('maps a native record into a validated civil-date domain entity', () {
      final response = ExpenseResponse.fromJson({
        'id': '9',
        'amount': 300,
        'category': 'other',
        'description': 'Game',
        'occurred_on': '2026-10-05 00:00:00.000Z',
        'created': '2026-10-06 19:24:29.000Z',
      });

      expect(response.amount, 300);
      final entity = response.toEntity();

      expect(entity.id, '9');
      expect(entity.cents.cents, 300);
      expect(entity.description, 'Game');
      expect(entity.occurredOn, DateTime(2026, 10, 5));
      expect(entity.category, ExpenseCategoryEnum.other);
    });

    for (final category in ExpenseCategoryEnum.values) {
      test('recognizes the API category ${category.value}', () {
        final response = ExpenseResponse.fromJson({
          'id': '9',
          'amount': 300,
          'description': 'Game',
          'occurred_on': '2026-10-05 00:00:00.000Z',
          'category': category.value,
        });

        expect(response.category, category);
        expect(response.toEntity().category, category);
      });
    }

    test('rejects categories outside the API contract', () {
      expect(
        () => ExpenseResponse.fromJson({
          'id': '9',
          'amount': 300,
          'description': 'Game',
          'category': 'unknown',
          'occurred_on': '2026-10-05 00:00:00.000Z',
        }),
        throwsStateError,
      );
    });

    for (final amount in [0, -300]) {
      test('rejects $amount cents during conversion', () {
        final response = ExpenseResponse(
          id: '9',
          amount: amount,
          category: .other,
          description: 'Game',
          occurredOn: DateTime(2026, 10, 5),
        );

        expect(response.toEntity, throwsArgumentError);
      });
    }
  });
}
