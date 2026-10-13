import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';
import 'package:cordato/features/metrics/presentation/extensions/expense_metrics_categories_extension.dart';

void main() {
  test('filters nonpositive totals and stably sorts without changing input or percentages', () {
    const categories = [
      ExpenseCategoryMetricsEntity(
        percentage: 0,
        totalAmount: 0,
        category: 'zero',
      ),
      ExpenseCategoryMetricsEntity(
        totalAmount: 200,
        percentage: 12.34,
        category: 'first-tie',
      ),
      ExpenseCategoryMetricsEntity(
        percentage: 0,
        totalAmount: -1,
        category: 'negative',
      ),
      ExpenseCategoryMetricsEntity(
        percentage: 50,
        totalAmount: 300,
        category: 'largest',
      ),
      ExpenseCategoryMetricsEntity(
        totalAmount: 200,
        percentage: 37.66,
        category: 'second-tie',
      ),
    ];
    final original = List.of(categories);
    final pages = categories.cardPages;

    expect(categories, original);
    expect(pages.single[1].percentage, 12.34);
    expect(identical(pages.single[1], categories[1]), isTrue);
    expect(pages.single, [categories[3], categories[1], categories[4]]);
  });

  for (final count in [1, 2, 3, 4, 5, 6, 7, 8, 10, 18]) {
    test(
      'groups $count categories into pages of two or three and hides a lone remainder',
      () {
        final categories = [
          for (int index = 0; index < count; index++)
            ExpenseCategoryMetricsEntity(
              percentage: 1.25,
              category: 'category-$index',
              totalAmount: count - index,
            ),
        ];
        final pages = categories.cardPages;
        final visibleCount = count % 3 == 1 ? count - 1 : count;

        expect(pages.length, (visibleCount / 3).ceil());
        expect(
          pages.every((page) => page.length == 2 || page.length == 3),
          isTrue,
        );
        expect(pages.expand((page) => page), categories.take(visibleCount));
        if (pages.length > 1) expect(pages[1].first, categories[3]);
      },
    );
  }

  test('makes no placeholder pages when no positive category is available', () {
    expect(<ExpenseCategoryMetricsEntity>[].cardPages, isEmpty);
    expect(
      const [
        ExpenseCategoryMetricsEntity(
          percentage: 0,
          totalAmount: 0,
          category: 'other',
        ),
      ].cardPages,
      isEmpty,
    );
  });
}
