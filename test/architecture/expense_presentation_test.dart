import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('expense listing does not couple to form Bloc or other features', () {
    final violations = <String>[];
    final imports = RegExp(r'''import\s+['"]([^'"]+)['"]''');

    for (final file
        in Directory('lib/features/expense/presentation/screens/expenses')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      for (final match in imports.allMatches(file.readAsStringSync())) {
        final dependency = match.group(1)!;
        if (dependency.contains('/screens/expense/') ||
            (dependency.startsWith('package:cordato/features/') &&
                !dependency.startsWith('package:cordato/features/core/') &&
                !dependency.startsWith('package:cordato/features/expense/'))) {
          violations.add('${file.path}: $dependency');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('expense presentation uses Bloc and pure application contracts', () {
    final violations = <String>[];
    for (final file
        in Directory('lib/features/expense/presentation')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      for (final forbidden in [
        'package:command_it/',
        '/presentation/commands/',
        '/infrastructure/',
        'package:pocketbase/',
        'package:dio/',
        'package:http/',
        'package:flutter_secure_storage/',
      ]) {
        if (source.contains(forbidden)) {
          violations.add('${file.path}: forbidden dependency $forbidden');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
