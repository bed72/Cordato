import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Information is a presentation-only feature', () {
    test('does not introduce domain, application or infrastructure layers', () {
      for (final layer in ['domain', 'application', 'infrastructure']) {
        expect(
          Directory('lib/features/information/$layer').existsSync(),
          isFalse,
        );
      }
    });

    test('depends only on its own presentation and shared UI capabilities', () {
      final imports = RegExp(r'''import\s+['"]([^'"]+)['"]''');
      final violations = <String>[];

      for (final file in Directory(
        'lib/features/information',
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        for (final match in imports.allMatches(file.readAsStringSync())) {
          final path = match.group(1)!;
          final allowed =
              path == 'package:material_ui/material_ui.dart' ||
              path == 'package:flutter_modular/flutter_modular.dart' ||
              path.startsWith('package:cordato/features/core/presentation/') ||
              path.startsWith(
                'package:cordato/features/information/presentation/',
              );
          if (!allowed) violations.add('${file.path}: $path');
        }
      }

      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });
}
