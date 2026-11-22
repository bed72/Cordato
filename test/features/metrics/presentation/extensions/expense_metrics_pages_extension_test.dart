import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';
import 'package:cordato/features/metrics/presentation/extensions/expense_metrics_categories_extension.dart';

void main() {
  group('Category tip visibility', () {
    const scenarios = {
      0: <int>[],
      1: <int>[],
      2: <int>[],
      3: <int>[],
      4: [1],
      5: <int>[],
      6: <int>[],
      7: [2],
      8: <int>[],
      9: <int>[],
      10: [3],
      11: <int>[],
      12: <int>[],
      13: [4],
      14: <int>[],
      15: <int>[],
      16: [5],
      17: <int>[],
      18: <int>[],
    };

    for (final scenario in scenarios.entries) {
      test('${scenario.key} categories show the tip on ${scenario.value}', () {
        final categories = _categories(scenario.key);
        final pages = categories.cardPages;
        final originalPages = [for (final page in pages) List.of(page)];

        final tipPages = [
          for (var index = 0; index < pages.length; index++)
            if (pages.showsCategoryTipAt(index)) index,
        ];

        expect(tipPages, scenario.value);
        expect(pages, originalPages);
        expect(pages.length, (scenario.key / 3).ceil());
        expect(pages.expand((page) => page), orderedEquals(categories));
      });
    }

    test('does not count hidden categories towards the remainder', () {
      final categories = [
        ..._categories(3),
        const ExpenseCategoryMetricsEntity(
          category: 'zero',
          total: 0,
          percentage: 0,
        ),
        const ExpenseCategoryMetricsEntity(
          category: 'negative',
          total: -1,
          percentage: 0,
        ),
      ];
      final pages = categories.cardPages;

      expect(pages, hasLength(1));
      expect(pages.showsCategoryTipAt(0), isFalse);
    });

    test(
      'hides the tip when removing the lone category fills the previous page',
      () {
        final categories = _categories(4);
        final before = categories.cardPages;
        final after = categories.take(3).toList().cardPages;

        expect(before.showsCategoryTipAt(1), isTrue);
        expect(after.showsCategoryTipAt(0), isFalse);
        expect(after.showsCategoryTipAt(1), isFalse);
      },
    );

    test('hides the tip when adding a second category to the final page', () {
      final before = _categories(4).cardPages;
      final after = _categories(5).cardPages;

      expect(before.showsCategoryTipAt(1), isTrue);
      expect(after.showsCategoryTipAt(1), isFalse);
      expect(before, hasLength(2));
      expect(after, hasLength(2));
    });

    for (final index in [-1, 2, 99]) {
      test('ignores invalid page index $index without indexing the list', () {
        expect(_categories(4).cardPages.showsCategoryTipAt(index), isFalse);
      });
    }

    test('does not show a tip on an empty page collection', () {
      final pages = <List<ExpenseCategoryMetricsEntity>>[];

      expect(pages.showsCategoryTipAt(0), isFalse);
      expect(pages.showsCategoryTipAt(-1), isFalse);
    });
  });
}

List<ExpenseCategoryMetricsEntity> _categories(int count) => [
  for (var index = 0; index < count; index++)
    ExpenseCategoryMetricsEntity(
      category: 'category-$index',
      total: count - index,
      percentage: 1.25,
    ),
];
