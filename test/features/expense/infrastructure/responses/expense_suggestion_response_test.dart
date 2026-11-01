import 'package:flutter_test/flutter_test.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_suggestion_response.dart';

void main() {
  for (final attributes in [
    {'description': 'Mercado'},
    {'description': 'Mercado', 'amount': null},
  ]) {
    test('accepts optional amount in $attributes', () {
      final entity = ExpenseSuggestionResponse.fromJson({
        'id': 'market',
        'attributes': attributes,
        'type': 'expense-suggestions',
      }).toEntity();

      expect(entity.id, 'market');
      expect(entity.cents, isNull);
      expect(entity.description, 'Mercado');
    });
  }

  test('maps amount to integer cents', () {
    expect(
      ExpenseSuggestionResponse.fromJson({
        'id': 'rent',
        'attributes': {'description': 'Aluguel', 'amount': 160000},
      }).toEntity().cents,
      160000,
    );
  });

  for (final amount in ['160000', 1600.0, true]) {
    test('rejects invalid amount type $amount', () {
      expect(
        () => ExpenseSuggestionResponse.fromJson({
          'id': 'rent',
          'attributes': {'description': 'Aluguel', 'amount': amount},
        }),
        throwsA(isA<TypeError>()),
      );
    });
  }

  test('does not hide malformed required fields', () {
    expect(
      () =>
          ExpenseSuggestionResponse.fromJson({'id': 'rent', 'attributes': {}}),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => ExpenseSuggestionResponse.fromJson({}),
      throwsA(isA<TypeError>()),
    );
  });
}
