import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';
import 'package:cordato/features/core/infrastructure/clients/http/mappers/response_mapper.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

void main() {
  test('preserves status and type without exposing remote messages', () {
    final errors = ResponseMapper.fromException(
      HttpResponseException(
        response: const Responses(
          status: 429,
          body: {
            'type': 'general_rate_limit_exceeded',
            'message': 'Remote content must not reach the UI',
          },
        ),
      ),
    );

    final failure = errors.errors.single;
    expect(failure.status, '429');
    expect(failure.code, 'general_rate_limit_exceeded');
    expect(failure.title, isNull);
    expect(failure.detail, isNull);
    expect(failure.pointer, isNull);
    expect(failure.parameter, isNull);
  });

  test('preserves status without Appwrite metadata', () {
    final errors = ResponseMapper.fromException(
      HttpResponseException(response: const Responses(status: 503, body: {})),
    );

    expect(errors.errors.single.status, '503');
    expect(errors.errors.single.code, isNull);
  });

  for (final scenario in [
    (name: 'connection', failure: HttpTransportException(failure: .connection)),
    (name: 'timeout', failure: HttpTransportException(failure: .timeout)),
    (name: 'cancelled', failure: HttpTransportException(failure: .cancelled)),
    (name: 'local failure', failure: HttpUnexpectedException()),
  ]) {
    test('uses safe fallback for ${scenario.name}', () {
      final errors = ResponseMapper.fromException(scenario.failure);

      expect(errors.errors.single.status, isNull);
      expect(
        errors.errors.single.detail,
        'Não foi possível processar a resposta.',
      );
    });
  }

  test('invalid successful envelope remains a parsing failure', () {
    expect(
      () => ResponseMapper.fromException(
        HttpInvalidResponseException(status: 200),
      ),
      throwsFormatException,
    );
  });

  test('does not mask invalid type metadata', () {
    expect(
      () => ResponseMapper.fromException(
        HttpResponseException(
          response: const Responses(status: 400, body: {'type': 42}),
        ),
      ),
      throwsA(isA<TypeError>()),
    );
  });
}
