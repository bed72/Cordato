import 'package:cordato/features/core/presentation/validators/validation.dart';

import 'package:cordato/features/expense/presentation/states/expense_form_state.dart';
import 'package:cordato/features/expense/presentation/validators/expense_date_validation.dart';
import 'package:cordato/features/expense/presentation/validators/expense_description_validation.dart';

final class const ExpenseFormValidator({
  required final ExpenseDateValidation dateValidation,
  required final ExpenseDescriptionValidation descriptionValidation,
}) {
  ({ExpenseFormState state, bool isValid}) call(ExpenseFormState state) {
    final date = dateValidation(state.date);
    final description = descriptionValidation(state.description);
    final isValid = date is Valid && description is Valid;

    return (
      isValid: isValid,
      state: state.copyWith(
        dateFailure: switch (date) {
          Valid() => null,
          Invalid(:final message) => message,
        },
        descriptionFailure: switch (description) {
          Valid() => null,
          Invalid(:final message) => message,
        },
        clearDateFailure: date is Valid,
        clearDescriptionFailure: description is Valid,
      ),
    );
  }
}
