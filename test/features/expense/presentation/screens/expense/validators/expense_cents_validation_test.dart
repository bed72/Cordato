import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_cents_validation.dart';

void main() {
  const validator = ExpenseCentsValidation();

  for (final cents in [0, -1, -300]) {
    test('rejects $cents cents with a localized field error', () {
      expect(
        validator(cents),
        isA<Invalid<int>>().having(
          (data) => data.message,
          'message',
          'Informe um valor maior que zero',
        ),
      );
    });
  }

  for (final cents in [1, 300, 123456789]) {
    test('preserves $cents positive cents without conversion', () {
      expect(
        validator(cents),
        isA<Valid<int>>().having((result) => result.value, 'value', cents),
      );
    });
  }
}
