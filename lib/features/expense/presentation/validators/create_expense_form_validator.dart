import 'package:cordato/features/core/presentation/validators/validation.dart';

import 'package:cordato/features/expense/presentation/validators/expense_date_validation.dart';
import 'package:cordato/features/expense/presentation/validators/expense_cents_validation.dart';
import 'package:cordato/features/expense/presentation/validators/expense_description_validation.dart';

final class const CreateExpenseFormValidator({
  required final ExpenseDateValidation _dateValidation,
  required final ExpenseCentsValidation _centsValidation,
  required final ExpenseDescriptionValidation _descriptionValidation,
}) {
  ({
    ValidationResult<int> cents,
    ValidationResult<String> description,
    ValidationResult<DateTime?> occurredOn,
  })
  call({
    required int cents,
    required String description,
    required DateTime? occurredOn,
  }) => (
    cents: _centsValidation(cents),
    occurredOn: _dateValidation(occurredOn),
    description: _descriptionValidation(description),
  );
}
