import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/user/presentation/validators/name_validation.dart';

void main() {
  const validation = NameValidation();

  group('Name length after trim', () {
    for (final name in ['', '   ', 'A', ' A ', 'a' * 33, '😀' * 33]) {
      test('rejects ${name.runes.length} code points: $name', () {
        expect(validation(name), isA<Invalid<String>>());
      });
    }

    for (final name in ['Al', '  Gabriel  ', 'a' * 32, '😀' * 32]) {
      test('accepts ${name.runes.length} code points: $name', () {
        expect(
          validation(name),
          isA<Valid<String>>().having(
            (validName) => validName.value,
            'value',
            name.trim(),
          ),
        );
      });
    }
  });
}
