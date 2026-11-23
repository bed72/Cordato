import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';

void main() {
  test(
    'retains the next page number and copies items into an immutable snapshot',
    () {
      final expense = ExpenseEntity(
        id: 15,
        description: 'Lanche',
        category: .other,
        cents: .create(cents: 10000),
        occurredOn: DateTime(2026, 10, 8),
      );
      final items = [expense];
      final page = ExpensePageEntity(items: items, nextPage: 2);

      items.clear();

      expect(page.nextPage, 2);
      expect(page.items.single, same(expense));
      expect(() => page.items.clear(), throwsUnsupportedError);
    },
  );

  test('represents an empty final page without links', () {
    final page = ExpensePageEntity(items: [], nextPage: null);

    expect(page.items, isEmpty);
    expect(page.nextPage, isNull);
  });
}
