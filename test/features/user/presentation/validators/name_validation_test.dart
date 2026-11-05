import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
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

  group('Remote name errors', () {
    for (final error in [
      const ErrorEntity(
        status: '400',
        pointer: '/name',
        code: 'validation_length_out_of_range',
        parameter: 'name',
      ),
      const ErrorEntity(status: '422', pointer: '/data/attributes/name'),
    ]) {
      test('recognizes ${error.status} ${error.pointer}', () {
        expect(validation.isFieldError(error), isTrue);
      });
    }

    for (final error in [
      const ErrorEntity(status: '400', pointer: '/avatar'),
      const ErrorEntity(status: '403', pointer: '/name'),
      const ErrorEntity(status: '422', pointer: '/name'),
      const ErrorEntity(status: '400'),
      const ErrorEntity(),
    ]) {
      test('leaves ${error.status} ${error.pointer} for general feedback', () {
        expect(validation.isFieldError(error), isFalse);
      });
    }
  });
}
