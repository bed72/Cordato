import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';
import 'package:cordato/features/expense/domain/enums/category_enum.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';

void main() {
  ExpensesTableData record({
    String category = 'other',
    int amount = 300,
    String? description = 'Game',
    String date = '2026-10-05',
  }) => ExpensesTableData(
    id: 9,
    profileId: 1,
    amount: amount,
    category: category,
    description: description,
    occurredOn: date,
  );

  test('maps typed record to integer ID, exact cents and civil date', () {
    final entity = ExpenseResponse.fromRecord(record()).toEntity();

    expect(entity.id, 9);
    expect(entity.cents.cents, 300);
    expect(entity.description, 'Game');
    expect(entity.occurredOn, DateTime(2026, 10, 5));
    expect(entity.category, CategoryEnum.other);
  });

  for (final category in CategoryEnum.values) {
    test('recognizes stored category ${category.value}', () {
      final entity = ExpenseResponse.fromRecord(
        record(category: category.value),
      ).toEntity();
      expect(entity.category, category);
    });
  }

  test('does not fabricate a default for an unknown category', () {
    expect(
      () => ExpenseResponse.fromRecord(record(category: 'unknown')),
      throwsStateError,
    );
  });

  test('projects nullable description as empty text', () {
    expect(
      ExpenseResponse.fromRecord(record(description: null))
          .toEntity()
          .description,
      '',
    );
  });

  test('preserves description without normalizing in mapping', () {
    expect(
      ExpenseResponse.fromRecord(record(description: '  Café  '))
          .toEntity()
          .description,
      '  Café  ',
    );
  });

  test('does not hide a malformed date', () {
    expect(
      () => ExpenseResponse.fromRecord(record(date: 'invalid')),
      throwsFormatException,
    );
  });

  for (final amount in [0, -300]) {
    test('rejects $amount cents during conversion', () {
      expect(
        () => ExpenseResponse.fromRecord(record(amount: amount)).toEntity(),
        throwsArgumentError,
      );
    });
  }
}
