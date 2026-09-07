import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/authentication/presentation/validators/code_validation.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';

void main() {
  const validator = CodeValidation();

  test('rejects an empty code', () {
    final result = validator('   ');

    expect(
      result,
      isA<Invalid<String>>().having(
        (validation) => validation.message,
        'message',
        'Código obrigatório',
      ),
    );
  });

  test('rejects a code that is not six digits', () {
    final result = validator('12345a');

    expect(
      result,
      isA<Invalid<String>>().having(
        (validation) => validation.message,
        'message',
        'Código inválido',
      ),
    );
  });

  test('returns a valid six-digit code', () {
    final result = validator('123456');

    expect(
      result,
      isA<Valid<String>>().having(
        (validation) => validation.value,
        'value',
        '123456',
      ),
    );
  });
}
