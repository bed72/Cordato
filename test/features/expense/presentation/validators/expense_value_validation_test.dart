import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/presentation/validators/expense_value_validation.dart';

void main() {
  const validation = ExpenseValueValidation();

  test('rejects a non-positive expense value', () {
    final data = validation(0);

    expect(data, isA<Invalid<int>>());
    expect((data as Invalid<int>).message, 'Informe um valor maior que zero');
  });

  test('accepts a positive expense value', () {
    final data = validation(1);

    expect(data, isA<Valid<int>>());
    expect((data as Valid<int>).value, 1);
  });

  test('rejects a value above the supported money limit', () {
    final data = validation(ExpenseEntity.maxAmount + 1);

    expect(data, isA<Invalid<int>>());
    expect(
      (data as Invalid<int>).message,
      'Informe um valor dentro do limite permitido',
    );
  });
}
