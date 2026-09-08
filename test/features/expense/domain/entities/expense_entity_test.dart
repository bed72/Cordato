import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';

void main() {
  test('normalizes the description and calendar date', () {
    final expense = ExpenseEntity.create(
      amount: 1500,
      description: '  Almoço  ',
      date: DateTime(2026, 9, 8, 12),
    );

    expect(expense, isNotNull);
    expect(expense!.description, 'Almoço');
    expect(expense.date, DateTime(2026, 9, 8));
  });

  test('rejects invalid expense values and descriptions', () {
    expect(
      ExpenseEntity.create(
        amount: 0,
        description: 'Almoço',
        date: DateTime(2026, 9, 8),
      ),
      isNull,
    );
    expect(
      ExpenseEntity.create(
        description: 'Almoço',
        date: DateTime(2026, 9, 8),
        amount: ExpenseEntity.maxAmount + 1,
      ),
      isNull,
    );
    expect(
      ExpenseEntity.create(
        amount: 1500,
        description: 'A',
        date: DateTime(2026, 9, 8),
      ),
      isNull,
    );
  });
}
