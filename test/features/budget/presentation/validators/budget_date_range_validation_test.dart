import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/budget/presentation/validators/budget_date_range_validation.dart';

void main() {
  const validation = BudgetDateRangeValidation();

  test('rejects a missing budget period', () {
    final result = validation(null);

    expect(result, isA<Invalid<DateTimeRange?>>());
    expect((result as Invalid<DateTimeRange?>).message, 'Selecione o período');
  });

  test('accepts a selected budget period', () {
    final period = DateTimeRange(
      end: DateTime(2026, 9, 30),
      start: DateTime(2026, 9, 1),
    );
    final result = validation(period);

    expect(result, isA<Valid<DateTimeRange?>>());
    expect((result as Valid<DateTimeRange?>).value, period);
  });
}
