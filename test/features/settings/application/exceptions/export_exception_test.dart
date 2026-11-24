import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/settings/application/exceptions/export_exception.dart';

void main() {
  test('preserves ordered errors and field metadata by identity', () {
    const errors = ErrorsEntity(
      errors: [
        ErrorEntity(code: 'first', pointer: '/expenses', parameter: 'id'),
        ErrorEntity(
          code: 'second',
          title: 'Seguro',
          detail: 'Descrição segura',
        ),
      ],
    );

    const exception = ExportException(errors: errors);

    expect(exception.errors, same(errors));
    expect(exception.errors.errors.map((error) => error.code), [
      'first',
      'second',
    ]);
    expect(exception.errors.errors.first.pointer, '/expenses');
    expect(exception.errors.errors.first.parameter, 'id');
  });
}
