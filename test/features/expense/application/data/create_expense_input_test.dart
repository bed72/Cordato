import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/application/data/create_expense_input.dart';

void main() {
  group('CreateExpenseInput', () {
    test('preserves the supplied description', () {
      final input = CreateExpenseInput(cents: 200, description: 'Contador');

      expect(input.description, 'Contador');
    });

    test('uses the current time when the occurrence date is omitted', () {
      final before = DateTime.now();
      final input = CreateExpenseInput(cents: 200, description: 'Contador');
      final after = DateTime.now();

      expect(input.occurredOn.isBefore(before), isFalse);
      expect(input.occurredOn.isAfter(after), isFalse);
    });

    test('preserves an explicitly supplied occurrence date', () {
      final occurredOn = DateTime(2026, 10, 5);
      final input = CreateExpenseInput(
        cents: 200,
        description: 'Contador',
        occurredOn: occurredOn,
      );

      expect(input.occurredOn, same(occurredOn));
    });

    test('uses the current time when the occurrence date is null', () {
      final before = DateTime.now();
      final input = CreateExpenseInput(
        cents: 200,
        description: 'Contador',
        occurredOn: null,
      );
      final after = DateTime.now();

      expect(input.occurredOn.isBefore(before), isFalse);
      expect(input.occurredOn.isAfter(after), isFalse);
    });

    for (final amount in [-200, 0, 1, 200]) {
      test('carries $amount cents without domain validation', () {
        final input = CreateExpenseInput(
          cents: amount,
          description: 'Contador',
        );

        expect(input.cents, amount);
      });
    }
  });
}
