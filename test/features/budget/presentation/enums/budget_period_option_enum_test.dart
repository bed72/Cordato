import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/budget/presentation/enums/budget_period_option_enum.dart';

void main() {
  test('weekly period includes seven days', () {
    final period = BudgetPeriodOptionEnum.weekly.periodStartingAt(
      DateTime(2026, 9, 19, 12),
    );

    expect(period?.end, DateTime(2026, 9, 25));
    expect(period?.start, DateTime(2026, 9, 19));
  });

  test('monthly period ends one day before the next monthly anniversary', () {
    final period = BudgetPeriodOptionEnum.monthly.periodStartingAt(
      DateTime(2026, 9, 19),
    );

    expect(period?.end, DateTime(2026, 10, 18));
    expect(period?.start, DateTime(2026, 9, 19));
  });

  test('monthly period clamps anniversaries to shorter months', () {
    final period = BudgetPeriodOptionEnum.monthly.periodStartingAt(
      DateTime(2027, 1, 31),
    );

    expect(period?.end, DateTime(2027, 2, 28));
  });

  test('custom period is supplied by the date range picker', () {
    expect(
      BudgetPeriodOptionEnum.custom.periodStartingAt(DateTime(2026, 9, 19)),
      isNull,
    );
  });
}
