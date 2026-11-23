import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/domain/enums/category_enum.dart';

void main() {
  test('expense categories match the API contract', () {
    expect(CategoryEnum.values.map((category) => category.value), [
      'food',
      'pets',
      'taxes',
      'health',
      'travel',
      'housing',
      'leisure',
      'shopping',
      'services',
      'transport',
      'education',
      'financing',
      'insurance',
      'investments',
      'personal_care',
      'subscriptions',
      'gifts_and_donations',
      'other',
    ]);
  });
}
