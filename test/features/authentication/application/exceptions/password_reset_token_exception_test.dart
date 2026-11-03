import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/authentication/application/exceptions/password_reset_token_exception.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

void main() {
  test('preserves the exact remote errors without exposing a token', () {
    const errors = ErrorsEntity(
      errors: [
        ErrorEntity(
          status: '400',
          pointer: '/token',
          code: 'validation_invalid_token',
          parameter: 'token',
        ),
      ],
    );
    final exception = PasswordResetTokenException(errors: errors);
    expect(exception.errors, same(errors));
  });
}
