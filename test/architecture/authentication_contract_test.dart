import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the authentication public boundary pure and passwordless', () {
    final importPattern = RegExp(r'''(?:import|export)\s+['"]([^'"]+)['"]''');
    final paths = [
      'lib/features/authentication/application/repositories/interface_authentication_repository.dart',
    ];

    for (final path in paths) {
      final source = File(path).readAsStringSync();
      final imports = importPattern
          .allMatches(source)
          .map((match) => match.group(1)!);

      expect(imports, isEmpty, reason: path);
      expect(
        source,
        isNot(matches(RegExp(r'password|cookie|secret', caseSensitive: false))),
        reason: path,
      );
    }
  });
}
