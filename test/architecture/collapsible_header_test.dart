import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'collapsible header is shared presentation without navigation or SDKs',
    () {
      final files = Directory('lib/features/core/presentation/widgets/headers')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      final imports = RegExp(r'''import\s+['"]([^'"]+)['"]''');
      final violations = <String>[];

      for (final file in files) {
        for (final match in imports.allMatches(file.readAsStringSync())) {
          final path = match.group(1)!;
          final allowed =
              path == 'dart:math' ||
              path == 'package:material_ui/material_ui.dart' ||
              path.startsWith('package:cordato/features/core/presentation/');
          if (!allowed) violations.add('${file.path}: $path');
        }
      }

      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );

  test(
    'scroll transition math is independent from Flutter and feature layers',
    () {
      final source = File(
        'lib/features/core/presentation/animations/collapsible_header_transition.dart',
      ).readAsStringSync();

      expect(RegExp(r'\b(?:import|export|part)\b').hasMatch(source), isFalse);
    },
  );
}
