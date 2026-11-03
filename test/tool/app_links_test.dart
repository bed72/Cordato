import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/app_links.dart';

void main() {
  const appleAppId = 'ABCDEFGHIJ.com.bed.cordato';
  final fingerprint = List.filled(32, 'ab').join(':');

  group('associationFiles', () {
    test(
      'generates Android associations for unique distribution certificates',
      () {
        final second = List.filled(32, 'CD').join(':');
        final files = associationFiles(
          appleAppId: appleAppId,
          androidSha256: [fingerprint, fingerprint.toUpperCase(), second],
        );

        expect(jsonDecode(files['assetlinks.json']!), [
          {
            'relation': ['delegate_permission/common.handle_all_urls'],
            'target': {
              'namespace': 'android_app',
              'package_name': 'com.bed.cordato',
              'sha256_cert_fingerprints': [fingerprint.toUpperCase(), second],
            },
          },
        ]);
      },
    );

    test(
      'limits Universal Links to verification and password reset callbacks',
      () {
        final files = associationFiles(
          appleAppId: appleAppId,
          androidSha256: [fingerprint],
        );

        expect(jsonDecode(files['apple-app-site-association']!), {
          'applinks': {
            'details': [
              {
                'appIDs': [appleAppId],
                'components': [
                  {'/': '/authentication/confirm-email'},
                  {'/': '/authentication/reset-password'},
                ],
              },
            ],
          },
        });
      },
    );

    for (final invalid in [
      '',
      'TEAM.com.other.app',
      'ABCDEFGHIJ.com.bed.cordato/',
    ]) {
      test('rejects invalid Apple identifier: "$invalid"', () {
        expect(
          () => associationFiles(
            appleAppId: invalid,
            androidSha256: [fingerprint],
          ),
          throwsFormatException,
        );
      });
    }

    for (final fingerprints in <List<String>>[
      [],
      ['AA:BB'],
      [List.filled(32, 'GG').join(':')],
      [fingerprint, 'invalid'],
    ]) {
      test('rejects invalid Android certificates: $fingerprints', () {
        expect(
          () => associationFiles(
            appleAppId: appleAppId,
            androidSha256: fingerprints,
          ),
          throwsFormatException,
        );
      });
    }
  });
}
