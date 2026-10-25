import 'package:flutter_test/flutter_test.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/user/application/exceptions/user_exception.dart';

void main() {
  test('preserves the original errors, including an empty list', () {
    for (final errors in [
      const ErrorsEntity(errors: []),
      const ErrorsEntity(errors: [ErrorEntity(detail: 'Falha')]),
    ]) {
      expect(UserException(errors: errors).errors, same(errors));
    }
  });
}
