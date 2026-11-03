import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/authentication/presentation/validators/password_reset_token_validation.dart';

void main() {
  const validation = PasswordResetTokenValidation();

  for (final query in [
    '',
    '?token=',
    '?token=%20',
    '?token=first&token=second',
    '?url=https://other.example',
  ]) {
    test('rejects missing, empty or ambiguous token: $query', () {
      expect(
        validation(Uri.parse('/authentication/reset-password$query')),
        isNull,
      );
    });
  }

  test('decodes a single opaque token once without normalizing it', () {
    expect(
      validation(
        Uri.parse(
          '/authentication/reset-password?token=fixture.%252B%2B.token',
        ),
      ),
      'fixture.%2B+.token',
    );
  });
}
