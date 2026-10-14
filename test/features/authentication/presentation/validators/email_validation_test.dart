import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';

void main() {
  const validator = EmailValidation();

  test('rejects an empty email', () {
    final data = validator('   ');

    expect(
      data,
      isA<Invalid<String>>().having(
        (validation) => validation.message,
        'message',
        'E-mail obrigatório',
      ),
    );
  });

  test('rejects an invalid email', () {
    final data = validator('invalid-email');

    expect(
      data,
      isA<Invalid<String>>().having(
        (validation) => validation.message,
        'message',
        'E-mail inválido',
      ),
    );
  });

  test('returns a trimmed valid email', () {
    final data = validator(' person@example.com ');

    expect(
      data,
      isA<Valid<String>>().having(
        (validation) => validation.value,
        'value',
        'person@example.com',
      ),
    );
  });
}
