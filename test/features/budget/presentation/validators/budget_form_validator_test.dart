import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/budget/presentation/states/budget_form_state.dart';
import 'package:cordato/features/budget/presentation/validators/budget_value_validation.dart';
import 'package:cordato/features/budget/presentation/validators/budget_form_validator.dart';
import 'package:cordato/features/budget/presentation/validators/budget_date_range_validation.dart';
import 'package:cordato/features/budget/presentation/validators/budget_description_validation.dart';

void main() {
  const validator = BudgetFormValidator(
    valueValidation: BudgetValueValidation(),
    dateRangeValidation: BudgetDateRangeValidation(),
    descriptionValidation: BudgetDescriptionValidation(),
  );

  test('returns failures for the missing required fields', () {
    final result = validator(const BudgetFormState());

    expect(result.isValid, isFalse);
    expect(result.state.valueFailure, 'Informe um valor maior que zero');
    expect(result.state.periodFailure, 'Selecione o período');
    expect(result.state.descriptionFailure, isNull);
  });

  test('accepts a complete budget form and clears previous failures', () {
    final state = BudgetFormState(
      value: 1000,
      description: 'Orçamento de setembro',
      period: DateTimeRange(
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 30),
      ),
      valueFailure: 'Erro anterior',
      periodFailure: 'Erro anterior',
      descriptionFailure: 'Erro anterior',
    );

    final result = validator(state);

    expect(result.isValid, isTrue);
    expect(result.state.valueFailure, isNull);
    expect(result.state.periodFailure, isNull);
    expect(result.state.descriptionFailure, isNull);
  });
}
