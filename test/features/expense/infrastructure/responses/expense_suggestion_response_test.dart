import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';
import 'package:cordato/features/expense/domain/enums/category_enum.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_suggestion_response.dart';

void main() {
  ExpensesTableData record({
    String category = 'housing',
    int amount = 160000,
    String? description = 'Aluguel',
  }) => ExpensesTableData(
    id: 9,
    profileId: 1,
    amount: amount,
    description: description,
    category: category,
    occurredOn: '2026-11-23',
  );

  test('maps integer ID and exact amount without changing description', () {
    final suggestion = ExpenseSuggestionResponse.fromRecord(
      record(description: '  Aluguel  '),
    ).toEntity();

    expect(suggestion.id, 9);
    expect(suggestion.cents, 160000);
    expect(suggestion.description, '  Aluguel  ');
  });

  for (final category in CategoryEnum.values) {
    test('preserves ${category.value} in suggestion entity', () {
      expect(
        ExpenseSuggestionResponse.fromRecord(record(category: category.value))
            .toEntity()
            .category,
        category,
      );
    });
  }

  for (final amount in [0, -100]) {
    test('rejects nonpositive cents $amount', () {
      expect(
        () =>
            ExpenseSuggestionResponse.fromRecord(record(amount: amount))
                .toEntity(),
        throwsArgumentError,
      );
    });
  }

  for (final category in ['', 'unknown']) {
    test('does not replace invalid category "$category"', () {
      expect(
        () => ExpenseSuggestionResponse.fromRecord(record(category: category)),
        throwsStateError,
      );
    });
  }

  test('null descriptions must be excluded before suggestion mapping', () {
    expect(
      () => ExpenseSuggestionResponse.fromRecord(record(description: null)),
      throwsA(isA<TypeError>()),
    );
  });
}
