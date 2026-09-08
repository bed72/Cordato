import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/validators/validation.dart';

final class BudgetDateRangeValidation implements Validation<DateTimeRange?> {
  const BudgetDateRangeValidation();

  @override
  ValidationResult<DateTimeRange?> call(DateTimeRange? value) {
    if (value == null) return const Invalid('Selecione o período');
    if (value.end.isBefore(value.start)) {
      return const Invalid('Período inválido');
    }

    return Valid(value);
  }
}
