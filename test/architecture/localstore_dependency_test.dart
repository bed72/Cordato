import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SQLite replaces the legacy Localstore dependency', () {
    final manifest = File('pubspec.yaml').readAsStringSync();
    final lockfile = File('pubspec.lock').readAsStringSync();
    expect(
      manifest,
      isNot(matches(RegExp(r'^\s+localstore:', multiLine: true))),
    );
    expect(
      lockfile,
      isNot(matches(RegExp(r'^\s+localstore:', multiLine: true))),
    );
    expect(manifest, contains('drift:'));
    for (final directory in ['lib', 'test']) {
      for (final file
          in Directory(directory)
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))) {
        expect(
          file.readAsStringSync(),
          isNot(
            matches(
              RegExp(
                r'''^\s*(import|export)\s+['"]package:localstore/''',
                multiLine: true,
              ),
            ),
          ),
          reason: file.path,
        );
      }
    }
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
