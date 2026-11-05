import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final resourcesDirectory = Directory('android/app/src/main/res/values');
  final stringDeclaration = RegExp(r'<string\s+name="([^"]+)"([^>]*)>');

  group('Android string resources', () {
    test('names identify their purpose and file context without duplicates', () {
      final declaredNames = <String>{};

      for (final file in resourcesDirectory.listSync().whereType<File>()) {
        if (!file.path.endsWith('.xml')) {
          continue;
        }

        final declarations = stringDeclaration.allMatches(
          file.readAsStringSync(),
        );
        if (declarations.isEmpty) {
          continue;
        }

        final filename = file.uri.pathSegments.last;
        final context = filename == 'strings.xml'
            ? 'app'
            : RegExp(r'^strings_([a-z][a-z0-9_]*)\.xml$')
                  .firstMatch(filename)
                  ?.group(1);

        expect(context, isNotNull, reason: file.path);

        for (final declaration in declarations) {
          final name = declaration.group(1)!;

          expect(
            name,
            matches(
              '^(failure|success|label|action|cd|msg|config)_${context}_[a-z][a-z0-9_]*\$',
            ),
            reason: file.path,
          );
          expect(
            declaredNames.add(name),
            isTrue,
            reason: 'Duplicate string: $name',
          );
        }
      }

      expect(declaredNames, isNotEmpty);
    });

    test('technical authentication values are explicitly non-translatable', () {
      final source = File(
        '${resourcesDirectory.path}/strings_authentication.xml',
      ).readAsStringSync();
      final declarations = stringDeclaration.allMatches(source);

      expect(declarations, isNotEmpty);

      for (final declaration in declarations) {
        expect(declaration.group(1), startsWith('config_authentication_'));
        expect(
          declaration.group(2),
          contains('translatable="false"'),
          reason: declaration.group(1),
        );
      }
    });

    test('native XML and Kotlin references resolve to declared strings', () {
      final declaredNames = <String>{};
      for (final file in resourcesDirectory.listSync().whereType<File>()) {
        if (!file.path.endsWith('.xml')) {
          continue;
        }

        declaredNames.addAll(
          stringDeclaration
              .allMatches(file.readAsStringSync())
              .map((declaration) => declaration.group(1)!),
        );
      }

      final referencePattern = RegExp(
        r'(?:R\.string\.|@string/)([a-z][a-z0-9_]*)',
      );
      final nativeFiles = Directory('android/app/src/main')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) => file.path.endsWith('.xml') || file.path.endsWith('.kt'),
          );

      for (final file in nativeFiles) {
        for (final reference in referencePattern.allMatches(
          file.readAsStringSync(),
        )) {
          expect(
            declaredNames,
            contains(reference.group(1)),
            reason: file.path,
          );
        }
      }
    });
  });
}
