import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/domain/value_objects/amount_value_object.dart';

void main() {
  group('AmountValueObject', () {
    for (final cents in [1, 200, 123456789]) {
      test('preserves $cents cents without conversion or rounding', () {
        final data = AmountValueObject.create(cents: cents);

        expect(data.cents, cents);
      });
    }

    for (final cents in [0, -1, -200]) {
      test('rejects $cents cents with a domain error', () {
        expect(
          () => AmountValueObject.create(cents: cents),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.invalidValue,
              'cents',
              cents,
            ),
          ),
        );
      });
    }

    test('compares equal amounts by cents rather than identity', () {
      final first = AmountValueObject.create(cents: 200);
      final second = AmountValueObject.create(cents: 200);

      expect(first, second);
      expect({first, second}, hasLength(1));
      expect(first.hashCode, second.hashCode);
      expect(identical(first, second), isFalse);
    });

    test('distinguishes different amounts', () {
      final first = AmountValueObject.create(cents: 200);
      final second = AmountValueObject.create(cents: 201);

      expect(first, isNot(second));
    });

    test('does not compare equal to a raw integer', () {
      final amount = AmountValueObject.create(cents: 200);

      expect(amount, isNot(200));
    });
  });
}
