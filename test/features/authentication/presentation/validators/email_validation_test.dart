import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';

void main() {
  const validate = EmailValidation();

  test('rejects an empty or whitespace-only email', () {
    for (final value in ['', '   ']) {
      expect(
        validate(value),
        isA<Invalid<String>>().having(
          (emailCheck) => emailCheck.message,
          'message',
          'E-mail obrigatório',
        ),
      );
    }
  });

  test('rejects an invalid email', () {
    for (final value in [
      'person',
      'person@',
      '@example.com',
      'person@example',
      'person example@example.com',
    ]) {
      expect(
        validate(value),
        isA<Invalid<String>>().having(
          (emailCheck) => emailCheck.message,
          'message',
          'E-mail inválido',
        ),
      );
    }
  });

  test('trims a valid email without changing its case', () {
    expect(
      validate('  Person+tag@Example.com  '),
      isA<Valid<String>>().having(
        (emailCheck) => emailCheck.value,
        'value',
        'Person+tag@Example.com',
      ),
    );
  });
}
