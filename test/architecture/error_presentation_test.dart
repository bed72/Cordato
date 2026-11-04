import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presentation does not expose raw remote error titles or details', () {
    final rawErrorText = RegExp(
      r'\b(?:error|errors|remaining|fieldError)\s*(?:\.\s*(?:first|firstOrNull)\s*\??)?\.\s*(?:detail|title)\b',
    );
    final violations = <String>[];

    for (final file in Directory(
      'lib/features',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') ||
          !file.uri.pathSegments.contains('presentation')) {
        continue;
      }
      if (rawErrorText.hasMatch(file.readAsStringSync())) {
        violations.add(file.path);
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
