import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'handwritten production code does not use the generic identifier result',
    () {
      final violations = <String>[];
      final genericName = RegExp(r'\bresult\b');
      final sources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) =>
                file.path.endsWith('.dart') && !file.path.endsWith('.g.dart'),
          );

      for (final source in sources) {
        if (genericName.hasMatch(source.readAsStringSync())) {
          violations.add(source.path);
        }
      }

      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );
}
