import 'package:cordato/features/core/presentation/validators/validation.dart';

import 'package:cordato/features/budget/presentation/states/budget_form_state.dart';
import 'package:cordato/features/budget/presentation/validators/budget_value_validation.dart';
import 'package:cordato/features/budget/presentation/validators/budget_date_range_validation.dart';

final class const BudgetFormValidator({
  required final BudgetValueValidation valueValidation,
  required final BudgetDateRangeValidation dateRangeValidation,
}) {
  ({BudgetFormState state, bool isValid}) call(BudgetFormState state) {
    final value = valueValidation(state.value);
    final period = dateRangeValidation(state.period);
    final isValid = value is Valid && period is Valid;

    return (
      isValid: isValid,
      state: state.copyWith(
        valueFailure: switch (value) {
          Valid() => null,
          Invalid(:final message) => message,
        },
        periodFailure: switch (period) {
          Valid() => null,
          Invalid(:final message) => message,
        },
        clearValueFailure: value is Valid,
        clearPeriodFailure: period is Valid,
      ),
    );
  }
}
