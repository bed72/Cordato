import 'package:flutter_test/flutter_test.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_suggestion_response.dart';

void main() {
  test('maps amount to integer cents', () {
    expect(
      ExpenseSuggestionResponse.fromJson({
        'id': 'rent',
        'description': 'Aluguel',
        'amount': 160000,
      }).toEntity().cents,
      160000,
    );
  });

  for (final amount in ['160000', 1600.0, true, null]) {
    test('rejects invalid amount type $amount', () {
      expect(
        () => ExpenseSuggestionResponse.fromJson({
          'id': 'rent',
          'description': 'Aluguel',
          'amount': amount,
        }),
        throwsA(isA<TypeError>()),
      );
    });
  }

  test('does not hide malformed required fields', () {
    expect(
      () => ExpenseSuggestionResponse.fromJson({'id': 'rent', 'amount': 100}),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => ExpenseSuggestionResponse.fromJson({}),
      throwsA(isA<TypeError>()),
    );
  });

  for (final amount in [0, -100]) {
    test('rejects nonpositive cents $amount', () {
      expect(
        () => ExpenseSuggestionResponse.fromJson({
          'id': 'rent',
          'description': 'Aluguel',
          'amount': amount,
        }).toEntity(),
        throwsArgumentError,
      );
    });
  }
}
