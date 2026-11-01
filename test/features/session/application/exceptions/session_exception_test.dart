import 'package:flutter_test/flutter_test.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/session/application/exceptions/session_exception.dart';

void main() {
  test('preserves the same application errors instance', () {
    const errors = ErrorsEntity(
      errors: [ErrorEntity(status: '403', detail: 'Forbidden.')],
    );
    final exception = SessionException(errors: errors);
    expect(exception.errors, same(errors));
  });
}
