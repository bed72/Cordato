import 'package:flutter_test/flutter_test.dart';
import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_suggestion_response.dart';

void main() {
  test('maps amount to integer cents', () {
    expect(
      ExpenseSuggestionResponse.fromJson({
        'id': 'rent',
        'description': 'Aluguel',
        'amount': 160000,
        'category': 'housing',
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
          'category': 'housing',
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
          'category': 'housing',
        }).toEntity(),
        throwsArgumentError,
      );
    });
  }

  group('Historical category', () {
    for (final category in ExpenseCategoryEnum.values) {
      test('preserves ${category.value} in the suggestion entity', () {
        final suggestion = ExpenseSuggestionResponse.fromJson({
          'id': 'history-record',
          'description': 'Gasto anterior',
          'amount': 100,
          'category': category.value,
        }).toEntity();

        expect(suggestion.category, category);
        expect(suggestion.id, 'history-record');
        expect(suggestion.description, 'Gasto anterior');
        expect(suggestion.cents, 100);
      });
    }

    for (final category in ['', 'unknown']) {
      test('does not replace invalid category "$category" with Others', () {
        expect(
          () => ExpenseSuggestionResponse.fromJson({
            'id': 'history-record',
            'description': 'Gasto anterior',
            'amount': 100,
            'category': category,
          }),
          throwsStateError,
        );
      });
    }

    for (final category in [null, 10, true]) {
      test('rejects invalid category type $category', () {
        expect(
          () => ExpenseSuggestionResponse.fromJson({
            'id': 'history-record',
            'description': 'Gasto anterior',
            'amount': 100,
            'category': category,
          }),
          throwsA(isA<TypeError>()),
        );
      });
    }

    test('rejects a missing category', () {
      expect(
        () => ExpenseSuggestionResponse.fromJson({
          'id': 'history-record',
          'description': 'Gasto anterior',
          'amount': 100,
        }),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
