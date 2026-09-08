import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/expense/presentation/validators/expense_description_validation.dart';

void main() {
  const validation = ExpenseDescriptionValidation();

  test('rejects an empty expense description', () {
    final result = validation('  ');

    expect(result, isA<Invalid<String>>());
    expect((result as Invalid<String>).message, 'Informe uma descrição');
  });

  test('accepts and trims an expense description', () {
    final result = validation('  Mercado  ');

    expect(result, isA<Valid<String>>());
    expect((result as Valid<String>).value, 'Mercado');
  });

  test('rejects an expense description outside the supported length', () {
    final result = validation('A');

    expect(result, isA<Invalid<String>>());
    expect(
      (result as Invalid<String>).message,
      'A descrição deve ter entre 2 e 128 caracteres',
    );
  });
}
