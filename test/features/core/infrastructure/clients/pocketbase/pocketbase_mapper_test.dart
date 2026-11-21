import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/pocketbase/pocketbase_mapper.dart';

void main() {
  test('preserves native field order, metadata and escaped pointers', () {
    final errors = PocketBaseMapper.fromException(
      ClientException(
        statusCode: 400,
        response: {
          'message': 'Remote validation',
          'data': {
            'password': {'code': 'validation_length', 'message': 'Too short'},
            'nested/~field': {
              'code': 'validation_required',
              'message': 'Required',
            },
          },
        },
      ),
    ).errors;

    expect(errors.map((error) => error.pointer), [
      '/password',
      '/nested~1~0field',
    ]);
    expect(errors.map((error) => error.parameter), [
      'password',
      'nested/~field',
    ]);
    expect(errors.map((error) => error.code), [
      'validation_length',
      'validation_required',
    ]);
    expect(errors.map((error) => error.detail), ['Too short', 'Required']);
    expect(errors.map((error) => error.status), everyElement('400'));
    expect(
      errors.map((error) => error.title),
      everyElement('Remote validation'),
    );
  });

  for (final status in [401, 403, 404, 429, 500]) {
    test('preserves HTTP $status without field metadata', () {
      final error = PocketBaseMapper.fromException(
        ClientException(
          statusCode: status,
          response: {'message': 'Remote failure', 'data': <String, dynamic>{}},
        ),
      ).errors.single;

      expect(error.status, status.toString());
      expect(error.detail, 'Remote failure');
      expect(error.pointer, isNull);
      expect(error.parameter, isNull);
    });
  }

  test('uses a safe fallback for transport failure without HTTP status', () {
    final error = PocketBaseMapper.fromException(ClientException())
        .errors
        .single;

    expect(error.status, isNull);
    expect(error.title, 'Erro desconhecido');
  });

  for (final failure in [
    StateError('unexpected'),
    const FormatException('invalid JSON'),
  ]) {
    test('does not hide ${failure.runtimeType} wrapped by the SDK', () {
      expect(
        () => PocketBaseMapper.fromException(
          ClientException(originalError: failure),
        ),
        throwsA(same(failure)),
      );
    });
  }
}
