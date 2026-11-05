import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/authentication/presentation/validators/password_validation.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';

void main() {
  const validate = PasswordValidation();

  test('rejects an empty password', () {
    expect(
      validate(''),
      isA<Invalid<String>>().having(
        (passwordCheck) => passwordCheck.message,
        'message',
        'Senha obrigatória',
      ),
    );
  });

  test('rejects passwords outside the supported length', () {
    for (final value in ['Abc1x', 'Abc12345678901234']) {
      expect(
        validate(value),
        isA<Invalid<String>>().having(
          (passwordCheck) => passwordCheck.message,
          'message',
          'A senha deve ter entre 6 e 16 caracteres',
        ),
      );
    }
  });

  test('requires an uppercase letter', () {
    expect(
      validate('abc123'),
      isA<Invalid<String>>().having(
        (passwordCheck) => passwordCheck.message,
        'message',
        'A senha deve conter uma letra maiúscula',
      ),
    );
  });

  test('requires a digit', () {
    expect(
      validate('Abcdef'),
      isA<Invalid<String>>().having(
        (passwordCheck) => passwordCheck.message,
        'message',
        'A senha deve conter um número',
      ),
    );
  });

  test('preserves valid passwords including boundary lengths and spaces', () {
    for (final value in [
      'Abc123',
      'Abc123456789',
      'Abc1234567890',
      'Abc1234567890123',
      ' Abc123 ',
    ]) {
      expect(
        validate(value),
        isA<Valid<String>>().having(
          (passwordCheck) => passwordCheck.value,
          'value',
          value,
        ),
      );
    }
  });

  for (final value in ['ABC123', 'ÁBC123']) {
    test('requires ASCII lowercase for $value', () {
      expect(
        validate(value),
        isA<Invalid<String>>().having(
          (passwordCheck) => passwordCheck.message,
          'message',
          'A senha deve conter uma letra minúscula',
        ),
      );
    });
  }

  test('accented uppercase does not replace ASCII uppercase', () {
    expect(
      validate('Ábc123'),
      isA<Invalid<String>>().having(
        (passwordCheck) => passwordCheck.message,
        'message',
        'A senha deve conter uma letra maiúscula',
      ),
    );
  });

  test('non-ASCII digits do not replace ASCII digits', () {
    expect(
      validate('Abc١٢٣'),
      isA<Invalid<String>>().having(
        (passwordCheck) => passwordCheck.message,
        'message',
        'A senha deve conter um número',
      ),
    );
  });

  test('counts Unicode code points rather than UTF-16 units', () {
    final accepted = 'Ab1${List.filled(13, '😀').join()}';
    final rejected = '$accepted😀';
    expect(
      validate(accepted),
      isA<Valid<String>>().having(
        (passwordCheck) => passwordCheck.value,
        'value',
        accepted,
      ),
    );
    expect(validate(rejected), isA<Invalid<String>>());
  });
}
