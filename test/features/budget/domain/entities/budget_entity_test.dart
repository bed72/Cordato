import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/budget/domain/entities/budget_entity.dart';

void main() {
  test('normalizes the description and calendar dates', () {
    final budget = BudgetEntity.create(
      amount: 100000,
      description: '  Viagem  ',
      endDate: DateTime(2026, 9, 30, 20),
      startDate: DateTime(2026, 9, 1, 13),
    );

    expect(budget, isNotNull);
    expect(budget!.description, 'Viagem');
    expect(budget.endDate, DateTime(2026, 9, 30));
    expect(budget.startDate, DateTime(2026, 9, 1));
  });

  test('keeps an empty description optional', () {
    final budget = BudgetEntity.create(
      amount: 100000,
      description: '   ',
      endDate: DateTime(2026, 9, 30),
      startDate: DateTime(2026, 9, 1),
    );

    expect(budget?.description, isNull);
  });

  test('rejects invalid budget values', () {
    expect(
      BudgetEntity.create(
        amount: 0,
        description: '',
        endDate: DateTime(2026, 9, 30),
        startDate: DateTime(2026, 9, 1),
      ),
      isNull,
    );
    expect(
      BudgetEntity.create(
        description: '',
        endDate: DateTime(2026, 9, 30),
        startDate: DateTime(2026, 9, 1),
        amount: BudgetEntity.maxAmount + 1,
      ),
      isNull,
    );
    expect(
      BudgetEntity.create(
        amount: 100000,
        description: '',
        endDate: DateTime(2026, 9, 1),
        startDate: DateTime(2026, 9, 30),
      ),
      isNull,
    );
    expect(
      BudgetEntity.create(
        amount: 100000,
        description: 'A',
        endDate: DateTime(2026, 9, 30),
        startDate: DateTime(2026, 9, 1),
      ),
      isNull,
    );
  });
}
