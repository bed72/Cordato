import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/domain/enums/category_enum.dart';

void main() {
  group('Stored category parsing', () {
    for (final category in CategoryEnum.values) {
      test('parses ${category.value}', () {
        expect(CategoryEnum.fromValue(category.value), category);
      });
    }

    for (final value in ['', 'unknown', 'FOOD', ' food ', 'personalCare']) {
      test('rejects "$value" without normalization or fallback', () {
        expect(() => CategoryEnum.fromValue(value), throwsStateError);
      });
    }
  });
}
