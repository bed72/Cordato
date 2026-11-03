import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presentation uses animated Lucide icons through the shared renderer', () {
    final violations = <String>[];
    const renderer =
        'lib/features/core/presentation/widgets/icons/icon_widget.dart';

    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      if (RegExp(r'\b(?:Icons\.|CupertinoIcons\.|IconData\b|Icon\s*\()')
          .hasMatch(source)) {
        violations.add('${file.path}: static icon API');
      }
      if (file.path != renderer &&
          RegExp(r'\bLucideAnimatedIcon\s*\(').hasMatch(source)) {
        violations.add('${file.path}: bypasses the shared icon renderer');
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
