import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/domain/value_objects/amount_value_object.dart';

void main() {
  group('ExpenseEntity', () {
    test('represents a registered expense independently of JSON:API', () {
      final occurredOn = DateTime(2026, 10, 5);
      final amount = AmountValueObject.create(cents: 200);
      final expense = ExpenseEntity(
        id: '8',
        cents: amount,
        category: .other,
        occurredOn: occurredOn,
        description: 'Contador',
      );

      expect(expense.id, '8');
      expect(expense.cents.cents, 200);
      expect(expense.cents, same(amount));
      expect(expense.occurredOn, occurredOn);
      expect(expense.description, 'Contador');
      expect(expense.category, ExpenseCategoryEnum.other);
    });
  });
}
