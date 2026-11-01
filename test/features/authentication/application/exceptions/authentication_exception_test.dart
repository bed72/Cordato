import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';

void main() {
  test('preserves the same errors including an empty list', () {
    for (final errors in [
      const ErrorsEntity(errors: []),
      const ErrorsEntity(
        errors: [
          ErrorEntity(title: 'Falha', pointer: '/email', parameter: 'email'),
        ],
      ),
    ]) {
      expect(AuthenticationException(errors: errors).errors, same(errors));
    }
  });
}
