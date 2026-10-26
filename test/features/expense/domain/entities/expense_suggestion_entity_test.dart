import 'package:flutter_test/flutter_test.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';

void main() {
  test('description-only suggestion does not fabricate an amount', () {
    final suggestion = ExpenseSuggestionEntity(id: '1', description: 'Mercado');
    expect(suggestion.cents, isNull);
    expect(suggestion.description, 'Mercado');
  });

  test('preserves integer cents without rounding', () {
    final suggestion = ExpenseSuggestionEntity(
      id: '1',
      description: 'Aluguel',
      cents: 9007199254740993,
    );
    expect(suggestion.cents, 9007199254740993);
  });

  for (final amount in [0, -1]) {
    test('rejects invalid amount $amount', () {
      expect(
        () => ExpenseSuggestionEntity(
          id: '1',
          description: 'Aluguel',
          cents: amount,
        ),
        throwsArgumentError,
      );
    });
  }
}
