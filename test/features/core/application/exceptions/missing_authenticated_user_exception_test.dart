import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/application/exceptions/missing_authenticated_user_exception.dart';

void main() {
  test('exposes the shared missing identity application errors', () {
    const failure = MissingAuthenticatedUserException();

    expect(failure, isA<Exception>());
    expect(failure.errors.errors, hasLength(1));
    expect(failure.errors.errors.single.title, 'Usuário não identificado');
    expect(
      failure.errors.errors.single.detail,
      'Não foi possível identificar o usuário.',
    );
    expect(failure.errors, same(failure.errors));
  });
}
