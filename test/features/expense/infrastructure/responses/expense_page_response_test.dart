import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/infrastructure/responses/expense_page_response.dart';

void main() {
  test('parses the collection and preserves opaque pagination links', () {
    final page = ExpensePageResponse.fromJson({
      'data': [
        {
          'id': '15',
          'type': 'expenses',
          'attributes': {
            'amount': 10000,
            'occurred_on': '2026-10-08',
            'description': 'Lanche',
            'category': 'other',
            'created_at': '2026-10-06T20:16:48+00:00',
          },
        },
      ],
      'links': {
        'next': 'https://trocado.test/api/expenses?page%5Bafter%5D=15',
        'prev': null,
      },
    });

    expect(page.items.single.id, '15');
    expect(page.items.single.amount, 10000);
    expect(page.items.single.occurredOn, DateTime(2026, 10, 8));
    expect(page.next, 'https://trocado.test/api/expenses?page%5Bafter%5D=15');
    expect(page.prev, isNull);
    expect(() => page.items.clear(), throwsUnsupportedError);
  });

  test('copies the supplied list instead of retaining mutable input', () {
    final items = ExpensePageResponse.fromJson({
      'data': [],
      'links': {'next': null, 'prev': null},
    }).items.toList();
    final page = ExpensePageResponse(items: items, next: null, prev: null);
    expect(identical(page.items, items), isFalse);
    expect(page.items, isEmpty);
  });
}
