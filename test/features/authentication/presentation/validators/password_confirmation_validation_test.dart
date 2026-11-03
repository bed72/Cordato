import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/authentication/presentation/validators/password_confirmation_validation.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';

void main() {
  const validation = PasswordConfirmationValidation();

  test('requires confirmation', () {
    expect(
      validation(password: 'NewPass1', confirmation: ''),
      isA<Invalid<String>>(),
    );
  });

  test('rejects mismatched passwords without normalizing them', () {
    expect(
      validation(password: ' NewPass1 ', confirmation: 'NewPass1'),
      isA<Invalid<String>>(),
    );
  });

  test('preserves matching passwords exactly', () {
    expect(
      validation(password: ' NewPass1 ', confirmation: ' NewPass1 '),
      isA<Valid<String>>().having(
        (result) => result.value,
        'value',
        ' NewPass1 ',
      ),
    );
  });
}
