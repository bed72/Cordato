import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/authentication/presentation/validators/password_validation.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';

void main() {
  const validate = PasswordValidation();

  test('rejects an empty password', () {
    expect(
      validate(''),
      isA<Invalid<String>>().having(
        (result) => result.message,
        'message',
        'Senha obrigatória',
      ),
    );
  });

  test('rejects passwords outside the supported length', () {
    for (final value in ['Abc1x', 'Abc1234567890']) {
      expect(
        validate(value),
        isA<Invalid<String>>().having(
          (result) => result.message,
          'message',
          'A senha deve ter entre 6 e 12 caracteres',
        ),
      );
    }
  });

  test('requires an uppercase letter', () {
    expect(
      validate('abc123'),
      isA<Invalid<String>>().having(
        (result) => result.message,
        'message',
        'A senha deve conter uma letra maiúscula',
      ),
    );
  });

  test('requires a digit', () {
    expect(
      validate('Abcdef'),
      isA<Invalid<String>>().having(
        (result) => result.message,
        'message',
        'A senha deve conter um número',
      ),
    );
  });

  test('preserves valid passwords including boundary lengths and spaces', () {
    for (final value in ['Abc123', 'Abc123456789', ' Abc123 ']) {
      expect(
        validate(value),
        isA<Valid<String>>().having((result) => result.value, 'value', value),
      );
    }
  });
}
