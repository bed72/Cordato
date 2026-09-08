import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/budget/presentation/validators/budget_value_validation.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';

void main() {
  const validation = BudgetValueValidation();

  test('rejects a non-positive budget value', () {
    final result = validation(0);

    expect(result, isA<Invalid<int>>());
    expect((result as Invalid<int>).message, 'Informe um valor maior que zero');
  });

  test('accepts a positive budget value', () {
    final result = validation(1);

    expect(result, isA<Valid<int>>());
    expect((result as Valid<int>).value, 1);
  });
}
