import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/expense/presentation/validators/expense_value_validation.dart';

void main() {
  const validation = ExpenseValueValidation();

  test('rejects a non-positive expense value', () {
    final result = validation(0);

    expect(result, isA<Invalid<int>>());
    expect((result as Invalid<int>).message, 'Informe um valor maior que zero');
  });

  test('accepts a positive expense value', () {
    final result = validation(1);

    expect(result, isA<Valid<int>>());
    expect((result as Valid<int>).value, 1);
  });
}
