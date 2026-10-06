import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';

void main() {
  test('expense categories match the API contract', () {
    expect(ExpenseCategoryEnum.values.map((category) => category.name), [
      'food',
      'health',
      'housing',
      'leisure',
      'shopping',
      'services',
      'transport',
      'education',
      'subscriptions',
      'other',
    ]);
  });
}
