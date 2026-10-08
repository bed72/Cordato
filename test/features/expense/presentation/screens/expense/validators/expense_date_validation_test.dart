import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_date_validation.dart';

void main() {
  const validator = ExpenseDateValidation();

  test('requires a date selected in the form', () {
    expect(
      validator(null),
      isA<Invalid<DateTime?>>().having(
        (result) => result.message,
        'message',
        'Selecione a data',
      ),
    );
  });

  test('preserves the selected date without changing its timezone', () {
    final date = DateTime.utc(2026, 10, 5, 23, 59);

    expect(
      validator(date),
      isA<Valid<DateTime?>>().having(
        (result) => result.value,
        'value',
        same(date),
      ),
    );
  });
}
