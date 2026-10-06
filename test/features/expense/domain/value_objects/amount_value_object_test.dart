import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/domain/value_objects/amount_value_object.dart';

void main() {
  group('AmountValueObject', () {
    for (final cents in [1, 200, 123456789]) {
      test('preserves $cents cents without conversion or rounding', () {
        final data = AmountValueObject.create(cents: cents);

        expect(data.isRight, isTrue);
        expect(data.right.cents, cents);
      });
    }

    for (final cents in [0, -1, -200]) {
      test('rejects $cents cents with a domain error', () {
        final data = AmountValueObject.create(cents: cents);

        expect(data.isLeft, isTrue);
        expect(data.left.errors, hasLength(1));
        expect(data.left.errors.single.title, 'Valor inválido');
        expect(
          data.left.errors.single.detail,
          'O valor da despesa deve ser maior que zero.',
        );
      });
    }

    test('compares equal amounts by cents rather than identity', () {
      final first = AmountValueObject.create(cents: 200).right;
      final second = AmountValueObject.create(cents: 200).right;

      expect(first, second);
      expect({first, second}, hasLength(1));
      expect(first.hashCode, second.hashCode);
      expect(identical(first, second), isFalse);
    });

    test('distinguishes different amounts', () {
      final first = AmountValueObject.create(cents: 200).right;
      final second = AmountValueObject.create(cents: 201).right;

      expect(first, isNot(second));
    });

    test('does not compare equal to a raw integer', () {
      final amount = AmountValueObject.create(cents: 200).right;

      expect(amount, isNot(200));
    });
  });
}
