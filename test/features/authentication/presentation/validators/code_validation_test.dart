import 'package:flutter_test/flutter_test.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/authentication/presentation/validators/code_validation.dart';

void main() {
  const validate = CodeValidation();
  for (final code in [
    '',
    ' ',
    '12345',
    '1234567',
    'abcdef',
    '12 345',
    '１２３４５６',
    '١٢٣٤٥٦',
    '12345\n6',
  ]) {
    test('rejects ${code.runes.toList()}', () {
      expect(validate(code), isA<Invalid<String>>());
    });
  }
  for (final code in ['012345', '000000', ' 012345 ']) {
    test('accepts ${code.runes.toList()} and preserves leading zeroes', () {
      expect(
        validate(code),
        isA<Valid<String>>().having(
          (validation) => validation.value,
          'value',
          code.trim(),
        ),
      );
    });
  }
}
