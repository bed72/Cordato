import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

void main() {
  test('transports the original errors and all metadata in their order', () {
    const first = ErrorEntity(
      title: 'Intervalo inválido',
      detail: 'Informe os dois limites.',
      status: '422',
      pointer: '/data/attributes/occurred_on',
      parameter: 'filter[from]',
    );
    const second = ErrorEntity(
      title: 'Categoria desconhecida',
      detail: 'Escolha uma categoria.',
      status: 'future-status',
      pointer: '/data/attributes/category',
      parameter: 'filter[category]',
    );
    final errors = ErrorsEntity(errors: [first, second]);
    final exception = CommandFailureException(errors: errors);

    expect(exception, isA<Exception>());
    expect(exception.errors, same(errors));
    expect(exception.errors.errors, same(errors.errors));
    expect(exception.errors.errors, [first, second]);
    expect(exception.errors.errors.first, same(first));
    expect(exception.errors.errors.last, same(second));
    expect(exception.errors.errors.first.title, 'Intervalo inválido');
    expect(exception.errors.errors.first.detail, 'Informe os dois limites.');
    expect(exception.errors.errors.first.status, '422');
    expect(
      exception.errors.errors.first.pointer,
      '/data/attributes/occurred_on',
    );
    expect(exception.errors.errors.first.parameter, 'filter[from]');
    expect(exception.errors.errors.last.status, 'future-status');
    expect(exception.errors.errors.last.parameter, 'filter[category]');
  });

  test('preserves missing metadata without introducing defaults', () {
    const errors = ErrorsEntity(errors: [ErrorEntity()]);
    const exception = CommandFailureException(errors: errors);
    final error = exception.errors.errors.single;

    expect(exception.errors, same(errors));
    expect(error.title, isNull);
    expect(error.detail, isNull);
    expect(error.status, isNull);
    expect(error.pointer, isNull);
    expect(error.parameter, isNull);
  });

  test('preserves an empty error list without fabricating a failure', () {
    final errors = ErrorsEntity(errors: []);
    final exception = CommandFailureException(errors: errors);

    expect(exception.errors, same(errors));
    expect(exception.errors.errors, same(errors.errors));
    expect(exception.errors.errors, isEmpty);
  });
}
