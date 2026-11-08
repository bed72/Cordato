import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Settings only composes Expense application contracts in infrastructure or its module', () {
    final violations = <String>[];
    final imports = RegExp(
      r'''import\s+['"]package:cordato/features/expense/([^'"]+)['"]''',
    );
    for (final file
        in Directory('lib/features/settings')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      for (final match in imports.allMatches(file.readAsStringSync())) {
        if ((!file.path.contains('/infrastructure/') &&
                !file.path.endsWith('/settings_module.dart')) ||
            !{
              'application/repositories/interface_export_repository.dart',
              'application/exceptions/expense_exception.dart',
            }.contains(match.group(1))) {
          violations.add('${file.path}: ${match.group(1)}');
        }
      }
    }
    expect(violations, isEmpty);
  });

  test('export keeps financial serialization out of core and plugin imports out of features', () {
    for (final file
        in Directory('lib/features')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      if (source.contains('package:share_plus/') ||
          source.contains('package:path_provider/')) {
        expect(file.path, startsWith('lib/features/core/infrastructure/'));
      }
      if (file.path.contains('/file_share/') ||
          file.path.endsWith('/interface_file_share_client.dart')) {
        expect(source, isNot(contains('features/expense/')), reason: file.path);
      }
    }
  });
}
