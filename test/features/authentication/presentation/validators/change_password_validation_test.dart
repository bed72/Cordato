import 'package:flutter_test/flutter_test.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/authentication/presentation/validators/change_password_validation.dart';
import 'package:cordato/features/authentication/presentation/validators/password_confirmation_validation.dart';

void main() {
  const validate = ChangePasswordValidation();
  const confirm = PasswordConfirmationValidation();

  test('requires current password without enforcing creation policy', () {
    expect(validate.current(''), isA<Invalid<String>>());
    expect(
      validate.current(' x '),
      isA<Valid<String>>().having(
        (passwordCheck) => passwordCheck.value,
        'value',
        ' x ',
      ),
    );
  });

  test('all three equal produces reuse error only', () {
    expect(
      validate(oldPassword: 'Abc123', password: 'Abc123'),
      isA<Invalid<String>>().having(
        (passwordCheck) => passwordCheck.message,
        'message',
        'A nova senha não pode ser igual à senha atual',
      ),
    );
    expect(
      confirm(password: 'Abc123', confirmation: 'Abc123'),
      isA<Valid<String>>(),
    );
  });

  test('reuse does not depend on confirmation and both errors can coexist', () {
    expect(
      validate(oldPassword: 'Abc123', password: 'Abc123'),
      isA<Invalid<String>>(),
    );
    expect(
      confirm(password: 'Abc123', confirmation: 'Abc456'),
      isA<Invalid<String>>().having(
        (passwordCheck) => passwordCheck.message,
        'message',
        'As senhas não coincidem',
      ),
    );
  });

  test('distinct valid password accepts exact case and spaces', () {
    for (final password in ['abcD123', ' Abcd123 ']) {
      expect(
        validate(oldPassword: 'Abcd123', password: password),
        isA<Valid<String>>().having(
          (passwordCheck) => passwordCheck.value,
          'value',
          password,
        ),
      );
    }
  });

  test('distinct new password still enforces shared policy', () {
    expect(
      validate(oldPassword: 'old', password: 'ABC123'),
      isA<Invalid<String>>(),
    );
  });

  test(
    'distinct new password with mismatched confirmation has no reuse error',
    () {
      expect(
        validate(oldPassword: 'old', password: 'Abc123'),
        isA<Valid<String>>(),
      );
      expect(
        confirm(password: 'Abc123', confirmation: ' Abc123'),
        isA<Invalid<String>>(),
      );
    },
  );

  test('requires confirmation', () {
    expect(
      confirm(password: 'Abc123', confirmation: ''),
      isA<Invalid<String>>().having(
        (passwordCheck) => passwordCheck.message,
        'message',
        'Confirme a nova senha',
      ),
    );
  });
}
