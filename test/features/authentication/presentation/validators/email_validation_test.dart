import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';

void main() {
  const validator = EmailValidation();

  test('rejects an empty email', () {
    final result = validator('   ');

    expect(
      result,
      isA<Invalid<String>>().having(
        (validation) => validation.message,
        'message',
        'E-mail obrigatório',
      ),
    );
  });

  test('rejects an invalid email', () {
    final result = validator('invalid-email');

    expect(
      result,
      isA<Invalid<String>>().having(
        (validation) => validation.message,
        'message',
        'E-mail inválido',
      ),
    );
  });

  test('returns a trimmed valid email', () {
    final result = validator(' person@example.com ');

    expect(
      result,
      isA<Valid<String>>().having(
        (validation) => validation.value,
        'value',
        'person@example.com',
      ),
    );
  });
}
