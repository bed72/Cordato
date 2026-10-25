import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';

void main() {
  test('preserves original errors including empty errors and metadata', () {
    for (final errors in [
      const ErrorsEntity(errors: []),
      const ErrorsEntity(
        errors: [
          ErrorEntity(
            title: 'Valor inválido',
            status: '422',
            pointer: '/data/attributes/amount',
            parameter: 'filter[from]',
          ),
        ],
      ),
    ]) {
      expect(ExpenseException(errors: errors).errors, same(errors));
    }
  });
}
