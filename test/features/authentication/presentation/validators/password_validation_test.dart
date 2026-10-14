import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/authentication/presentation/validators/password_validation.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';

void main() {
  const validator = PasswordValidation();

  test('rejects an empty password', () {
    expect(
      validator(''),
      isA<Invalid<String>>().having(
        (data) => data.message,
        'message',
        'Senha obrigatória',
      ),
    );
  });

  test('rejects passwords shorter than 6 or longer than 12 characters', () {
    for (final password in ['Ab123', 'Ab12345678901']) {
      expect(
        validator(password),
        isA<Invalid<String>>().having(
          (data) => data.message,
          'message',
          'A senha deve ter entre 6 e 12 caracteres',
        ),
      );
    }
  });

  test('requires an uppercase letter', () {
    expect(
      validator('abc123'),
      isA<Invalid<String>>().having(
        (data) => data.message,
        'message',
        'A senha deve conter uma letra maiúscula',
      ),
    );
  });

  test('requires a number', () {
    expect(
      validator('Abcdef'),
      isA<Invalid<String>>().having(
        (data) => data.message,
        'message',
        'A senha deve conter um número',
      ),
    );
  });

  test(
    'accepts passwords at both length limits without changing the value',
    () {
      for (final password in ['Abc123', 'Abcdefghij12']) {
        expect(
          validator(password),
          isA<Valid<String>>().having((data) => data.value, 'value', password),
        );
      }
    },
  );
}
