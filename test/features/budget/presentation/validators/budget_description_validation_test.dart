import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/budget/presentation/validators/budget_description_validation.dart';

void main() {
  const validation = BudgetDescriptionValidation();

  test('accepts an empty budget description', () {
    final result = validation('  ');

    expect(result, isA<Valid<String>>());
    expect((result as Valid<String>).value, isEmpty);
  });

  test('accepts and trims a budget description', () {
    final result = validation('  Orçamento de setembro  ');

    expect(result, isA<Valid<String>>());
    expect((result as Valid<String>).value, 'Orçamento de setembro');
  });

  test('rejects a description outside the supported length', () {
    final result = validation('A');

    expect(result, isA<Invalid<String>>());
    expect(
      (result as Invalid<String>).message,
      'A descrição deve ter entre 2 e 128 caracteres',
    );
  });
}
