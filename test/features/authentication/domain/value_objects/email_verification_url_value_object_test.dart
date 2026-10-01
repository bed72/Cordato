import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/authentication/domain/value_objects/email_verification_url_value_object.dart';

void main() {
  const base = 'https://api.cordato.cloud/api/';
  const signed =
      'https://api.cordato.cloud/api/email-verification/12/abc123?expires=123456&signature=abcdef012345';

  test('accepts only the expected signed HTTPS API URL', () {
    final url = EmailVerificationUrlValueObject.tryParse(signed, baseUrl: base);
    expect(url?.value, signed);
    expect(
      url,
      EmailVerificationUrlValueObject.tryParse(signed, baseUrl: base),
    );
    expect(
      url.hashCode,
      EmailVerificationUrlValueObject.tryParse(signed, baseUrl: base).hashCode,
    );
    for (final candidate in [
      null,
      'http://api.cordato.cloud/api/email-verification/12/abc123?expires=123456&signature=abcdef012345',
      signed.replaceFirst(
        'api.cordato.cloud',
        'api.cordato.cloud.attacker.net',
      ),
      signed.replaceFirst('api.cordato.cloud', 'api.cordato.cloud:8443'),
      signed.replaceFirst('https://', 'https://someone@'),
      signed.replaceFirst('/api/email-verification/', '/api/other/'),
      signed.replaceFirst('/12/abc123', '/12/abc123/extra'),
      signed.replaceFirst('signature=abcdef012345', 'signature='),
      '$signed&signature=abcdef012345',
      '$signed#fragment',
    ]) {
      expect(
        EmailVerificationUrlValueObject.tryParse(candidate, baseUrl: base),
        isNull,
      );
    }
  });
}
