import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
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
        'package:dio/',
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
