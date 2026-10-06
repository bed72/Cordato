import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/value_objects/amount_value_object.dart';

void main() {
  test(
    'preserves an immutable snapshot of the supplied expenses and links',
    () {
      final expense = ExpenseEntity(
        id: '15',
        cents: AmountValueObject.create(cents: 10000).right,
        occurredOn: DateTime(2026, 10, 8),
        description: 'Lanche',
        category: .other,
      );
      final items = [expense];
      final page = ExpensePageEntity(
        items: items,
        next: '?page[after]=15',
        prev: null,
      );
      items.clear();

      expect(page.items, [expense]);
      expect(page.next, '?page[after]=15');
      expect(page.prev, isNull);
      expect(() => page.items.clear(), throwsUnsupportedError);
    },
  );
}
