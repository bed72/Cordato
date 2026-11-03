import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/infrastructure/responses/expense_page_response.dart';

void main() {
  test('parses native items and derives page continuations', () {
    final page = ExpensePageResponse.fromJson({
      'items': [
        {
          'id': '15',
          'amount': 10000,
          'category': 'other',
          'description': 'Lanche',
          'occurred_on': '2026-10-08 00:00:00.000Z',
          'created': '2026-10-06 20:16:48.000Z',
        },
      ],
      'page': 1,
      'totalPages': 2,
    });

    expect(page.items.single.id, '15');
    expect(page.items.single.amount, 10000);
    expect(page.items.single.occurredOn, DateTime(2026, 10, 8));
    expect(page.next, '?page=2');
    expect(page.prev, isNull);
    expect(() => page.items.clear(), throwsUnsupportedError);
  });

  test('copies the supplied list instead of retaining mutable input', () {
    final items = ExpensePageResponse.fromJson({
      'items': [],
      'page': 1,
      'totalPages': 0,
    }).items.toList();
    final page = ExpensePageResponse(items: items, next: null, prev: null);
    expect(identical(page.items, items), isFalse);
    expect(page.items, isEmpty);
  });

  for (final pageNumber in [1, 2, 3]) {
    test('derives boundaries for page $pageNumber of 3', () {
      final page = ExpensePageResponse.fromJson({
        'items': [],
        'page': pageNumber,
        'totalPages': 3,
      });
      expect(page.prev, pageNumber > 1 ? '?page=${pageNumber - 1}' : null);
      expect(page.next, pageNumber < 3 ? '?page=${pageNumber + 1}' : null);
    });
  }

  for (final json in <Map<String, dynamic>>[
    {},
    {'items': [], 'page': '1', 'totalPages': 1},
    {'items': [], 'page': 1},
    {
      'items': [null],
      'page': 1,
      'totalPages': 1,
    },
  ]) {
    test('propagates malformed page $json', () {
      expect(
        () => ExpensePageResponse.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });
  }
}
