import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/budget/domain/entities/budget_entity.dart';

void main() {
  test('normalizes calendar dates', () {
    final budget = BudgetEntity.create(
      amount: 100000,
      endDate: DateTime(2026, 9, 30, 20),
      startDate: DateTime(2026, 9, 1, 13),
    );

    expect(budget, isNotNull);
    expect(budget!.amount, 100000);
    expect(budget.endDate, DateTime(2026, 9, 30));
    expect(budget.startDate, DateTime(2026, 9, 1));
  });

  test('rejects invalid budget values', () {
    expect(
      BudgetEntity.create(
        amount: 0,
        endDate: DateTime(2026, 9, 30),
        startDate: DateTime(2026, 9, 1),
      ),
      isNull,
    );
    expect(
      BudgetEntity.create(
        endDate: DateTime(2026, 9, 30),
        startDate: DateTime(2026, 9, 1),
        amount: BudgetEntity.maxAmount + 1,
      ),
      isNull,
    );
    expect(
      BudgetEntity.create(
        amount: 100000,
        endDate: DateTime(2026, 9, 1),
        startDate: DateTime(2026, 9, 30),
      ),
      isNull,
    );
  });
}
