import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/presentation/states/expense_form_state.dart';
import 'package:cordato/features/expense/presentation/validators/expense_date_validation.dart';
import 'package:cordato/features/expense/presentation/validators/expense_form_validator.dart';
import 'package:cordato/features/expense/presentation/validators/expense_value_validation.dart';
import 'package:cordato/features/expense/presentation/validators/expense_description_validation.dart';

void main() {
  const validator = ExpenseFormValidator(
    valueValidation: ExpenseValueValidation(),
    dateValidation: ExpenseDateValidation(),
    descriptionValidation: ExpenseDescriptionValidation(),
  );

  test('returns failures for every missing required field', () {
    final result = validator(const ExpenseFormState());

    expect(result.isValid, isFalse);
    expect(result.state.valueFailure, 'Informe um valor maior que zero');
    expect(result.state.dateFailure, 'Selecione a data');
    expect(result.state.descriptionFailure, 'Informe uma descrição');
  });

  test('accepts a complete expense form and clears previous failures', () {
    final state = ExpenseFormState(
      value: 1000,
      date: DateTime(2026, 9, 8),
      description: 'Mercado',
      valueFailure: 'Erro anterior',
      dateFailure: 'Erro anterior',
      descriptionFailure: 'Erro anterior',
    );

    final result = validator(state);

    expect(result.isValid, isTrue);
    expect(result.state.valueFailure, isNull);
    expect(result.state.dateFailure, isNull);
    expect(result.state.descriptionFailure, isNull);
  });
}
