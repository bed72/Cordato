import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/expense/presentation/validators/expense_date_validation.dart';

void main() {
  const validation = ExpenseDateValidation();

  test('rejects a missing expense date', () {
    final result = validation(null);

    expect(result, isA<Invalid<DateTime?>>());
    expect((result as Invalid<DateTime?>).message, 'Selecione a data');
  });

  test('accepts a selected expense date', () {
    final date = DateTime(2026, 9, 8);
    final result = validation(date);

    expect(result, isA<Valid<DateTime?>>());
    expect((result as Valid<DateTime?>).value, date);
  });
}
