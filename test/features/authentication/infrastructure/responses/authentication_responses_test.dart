import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/authentication/infrastructure/responses/sign_in_response.dart';

void main() {
  test(
    'sign-in reads token and the user relationship rather than the token id',
    () {
      final response = SignInResponse.fromJson({
        'data': {
          'id': 'access-token-id',
          'attributes': {'token': 'opaque-token', 'expires_at': 'invalid'},
          'relationships': {
            'user': {
              'data': {'id': 'user-id'},
            },
          },
        },
      });

      expect(response.userId, 'user-id');
      expect(response.token, 'opaque-token');
    },
  );

  test('sign-in does not require expiration metadata', () {
    final response = SignInResponse.fromJson({
      'data': {
        'attributes': {'token': 'token'},
        'relationships': {
          'user': {
            'data': {'id': 'user'},
          },
        },
      },
    });

    expect(response.token, 'token');
    expect(response.userId, 'user');
  });

  test(
    'sign-in rejects missing or incompatible required response attributes',
    () {
      for (final body in <Map<String, dynamic>>[
        {},
        {'data': []},
        {
          'data': {
            'attributes': {'token': 'token'},
          },
        },
        {
          'data': {
            'attributes': {'token': 1},
            'relationships': {
              'user': {
                'data': {'id': 'user'},
              },
            },
          },
        },
        {
          'data': {
            'attributes': {'token': 'token'},
            'relationships': {
              'user': {
                'data': {'id': 1},
              },
            },
          },
        },
      ]) {
        expect(() => SignInResponse.fromJson(body), throwsA(isA<TypeError>()));
      }
    },
  );

  test('JSON API errors preserve order and nullable source metadata', () {
    final response = ErrorsResponse.fromJson({
      'errors': [
        {
          'status': '422',
          'title': 'Validação',
          'detail': 'E-mail inválido',
          'source': {'pointer': '/data/attributes/email', 'parameter': 'email'},
        },
        {'detail': 'Outra falha'},
      ],
    });

    final errors = response.toEntity().errors;

    expect(errors, hasLength(2));
    expect(errors.first.status, '422');
    expect(errors.last.status, isNull);
    expect(errors.last.pointer, isNull);
    expect(errors.last.parameter, isNull);
    expect(errors.first.title, 'Validação');
    expect(errors.first.parameter, 'email');
    expect(errors.last.detail, 'Outra falha');
    expect(errors.first.detail, 'E-mail inválido');
    expect(errors.first.pointer, '/data/attributes/email');
  });

  test('an empty backend error list has a safe fallback', () {
    final errors = ErrorsResponse.fromJson({'errors': []}).toEntity().errors;

    expect(errors.single.title, 'Erro desconhecido');
    expect(errors.single.detail, 'Não foi possível processar a resposta.');
  });
}
