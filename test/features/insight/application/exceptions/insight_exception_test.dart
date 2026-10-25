import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/insight/application/exceptions/insight_exception.dart';

void main() {
  test('preserves the original errors, including an empty list', () {
    for (final errors in [
      const ErrorsEntity(errors: []),
      const ErrorsEntity(
        errors: [
          ErrorEntity(
            title: 'Filtro inválido',
            status: '422',
            pointer: '/filter/month',
            parameter: 'filter[month]',
          ),
        ],
      ),
    ]) {
      expect(InsightException(errors: errors).errors, same(errors));
    }
  });
}
