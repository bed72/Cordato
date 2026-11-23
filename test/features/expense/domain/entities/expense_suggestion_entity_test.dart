import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';
import 'package:cordato/features/expense/domain/enums/category_enum.dart';

void main() {
  test('preserves the historical category without a suggested amount', () {
    final suggestion = ExpenseSuggestionEntity(
      id: 1,
      description: 'Mercado',
      category: .food,
    );

    expect(suggestion.category, CategoryEnum.food);
    expect(suggestion.cents, isNull);
  });

  test('preserves an explicit Others category with integer cents', () {
    final suggestion = ExpenseSuggestionEntity(
      id: 2,
      description: 'Outro gasto',
      category: .other,
      cents: 100,
    );

    expect(suggestion.category, CategoryEnum.other);
    expect(suggestion.cents, 100);
  });

  for (final cents in [0, -1]) {
    test('rejects nonpositive suggested cents $cents', () {
      expect(
        () => ExpenseSuggestionEntity(
          id: 1,
          description: 'Mercado',
          category: .food,
          cents: cents,
        ),
        throwsArgumentError,
      );
    });
  }
}
