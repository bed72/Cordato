import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Localstore follows main with a resolved commit in the lockfile', () {
    final manifest = File('pubspec.yaml').readAsStringSync();
    final lockfile = File('pubspec.lock').readAsStringSync();
    final dependency = RegExp(
      r'localstore:\s+git:\s+url: https://github\.com/bed72/localstore\.git\s+ref: main\b',
    ).firstMatch(manifest);

    expect(dependency, isNotNull);
    expect(
      lockfile,
      contains('url: "https://github.com/bed72/localstore.git"'),
    );
    expect(lockfile, matches(r'resolved-ref: [0-9a-f]{40}'));
    expect(lockfile, contains('ref: main'));
  });

  test(
    'release authenticates the private dependency without embedding a token',
    () {
      final workflow = File('.github/workflows/android-release.yml')
          .readAsStringSync();

      expect(
        workflow,
        contains(
          r'LOCALSTORE_READ_TOKEN: ${{ secrets.LOCALSTORE_READ_TOKEN }}',
        ),
      );
      expect(
        workflow,
        contains('credential.https://github.com/bed72/localstore.git.helper'),
      );
      expect(workflow, contains('credential.useHttpPath'));
      expect(workflow, contains('flutter pub get --enforce-lockfile'));
      expect(
        workflow,
        contains('Secret obrigatório ausente: LOCALSTORE_READ_TOKEN'),
      );
      expect(workflow, isNot(contains('https://x-access-token:')));
    },
  );
}
