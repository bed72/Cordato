import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_description_validation.dart';

void main() {
  const validator = ExpenseDescriptionValidation();

  for (final description in ['', '   ', '\n\t']) {
    test('rejects an empty or whitespace-only description "$description"', () {
      expect(
        validator(description),
        isA<Invalid<String>>().having(
          (result) => result.message,
          'message',
          'Informe uma descrição',
        ),
      );
    });
  }

  for (final description in ['a', 'a' * 129, ' a ']) {
    test(
      'rejects an out-of-range description of ${description.length} code units',
      () {
        expect(
          validator(description),
          isA<Invalid<String>>().having(
            (result) => result.message,
            'message',
            'A descrição deve ter entre 2 e 128 caracteres',
          ),
        );
      },
    );
  }

  for (final description in ['ab', 'a' * 128, '😀' * 128]) {
    test(
      'accepts a boundary description of ${description.length} code units',
      () {
        expect(
          validator(description),
          isA<Valid<String>>().having(
            (result) => result.value,
            'value',
            description,
          ),
        );
      },
    );
  }

  test('trims the description while preserving internal spaces', () {
    expect(
      validator('  Compra de  mercado  '),
      isA<Valid<String>>().having(
        (result) => result.value,
        'value',
        'Compra de  mercado',
      ),
    );
  });
}
