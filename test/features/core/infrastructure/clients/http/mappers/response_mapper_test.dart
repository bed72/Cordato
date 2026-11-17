import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/http/mappers/response_mapper.dart';

void main() {
  DioException remoteFailure({Object? body, int status = 400}) {
    final request = RequestOptions(path: '/account');
    return DioException(
      requestOptions: request,
      type: .badResponse,
      response: Response<dynamic>(
        data: body,
        statusCode: status,
        requestOptions: request,
      ),
    );
  }

  test('preserves status and type without exposing remote messages', () {
    final errors = ResponseMapper.fromException(
      remoteFailure(
        status: 429,
        body: {
          'code': 429,
          'type': 'general_rate_limit_exceeded',
          'message': 'Remote content must not reach the UI',
        },
      ),
    );

    final failure = errors.errors.single;
    expect(failure.status, '429');
    expect(failure.title, isNull);
    expect(failure.detail, isNull);
    expect(failure.pointer, isNull);
    expect(failure.code, 'general_rate_limit_exceeded');
  });

  for (final body in [
    null,
    '',
    '<html>Unavailable</html>',
    <String, dynamic>{},
  ]) {
    test('preserves HTTP status for non-Appwrite body $body', () {
      final errors = ResponseMapper.fromException(
        remoteFailure(status: 503, body: body),
      );

      expect(errors.errors.single.code, isNull);
      expect(errors.errors.single.status, '503');
    });
  }

  test('uses safe fallback for transport errors', () {
    final errors = ResponseMapper.fromException(
      DioException(
        requestOptions: RequestOptions(path: '/account'),
        type: .connectionTimeout,
      ),
    );

    expect(errors.errors.single.status, isNull);
    expect(
      errors.errors.single.detail,
      'Não foi possível processar a resposta.',
    );
  });

  for (final failure in [
    StateError('unexpected'),
    const FormatException('bad'),
  ]) {
    test('propagates unexpected ${failure.runtimeType}', () {
      expect(
        () => ResponseMapper.fromException(
          DioException(
            requestOptions: RequestOptions(path: '/account'),
            error: failure,
          ),
        ),
        throwsA(same(failure)),
      );
    });
  }

  test('does not mask invalid type metadata', () {
    expect(
      () => ResponseMapper.fromException(remoteFailure(body: {'type': 42})),
      throwsA(isA<TypeError>()),
    );
  });
}
