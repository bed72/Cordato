import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/authentication/infrastructure/responses/sign_up_response.dart';
import 'package:cordato/features/authentication/infrastructure/responses/sign_in_response.dart';

void main() {
  test('sign-in maps token, expiration and user relationship', () {
    final response = SignInResponse.fromJson({
      'data': {
        'id': '2',
        'type': 'access-tokens',
        'attributes': {
          'token_type': 'Bearer',
          'token': 'example-token',
          'expires_at': '2026-09-28T18:30:06+00:00',
        },
        'relationships': {
          'user': {
            'data': {'type': 'users', 'id': '3'},
          },
        },
      },
    });

    expect(response.userId, '2');
    expect(response.token, 'example-token');
    expect(response.expiresAt, DateTime.utc(2026, 9, 28, 18, 30, 6));

    final entity = response.toEntity();

    expect(entity.userId, '2');
    expect(entity.token, 'example-token');
    expect(entity.expiresAt, DateTime.utc(2026, 9, 28, 18, 30, 6));
  });

  test('sign-up maps resource id and related user id', () {
    final response = SignUpResponse.fromJson({
      'data': {
        'id': '3',
        'type': 'sign-ups',
        'relationships': {
          'user': {
            'data': {'type': 'users', 'id': '3'},
          },
        },
      },
    });

    expect(response.userId, '3');
  });

  test(
    'validation error preserves detail, title, status and source pointer',
    () {
      final response = ErrorsResponse.fromJson({
        'errors': [
          {
            'status': '422',
            'title': 'Erro de validação',
            'source': {'pointer': '/data/type'},
            'detail': 'O campo data.type é obrigatório.',
          },
        ],
      });

      expect(response.errors, hasLength(1));
      expect(response.errors.single.status, '422');
      expect(response.errors.single.pointer, '/data/type');
      expect(response.errors.single.title, 'Erro de validação');
      expect(response.errors.single.detail, 'O campo data.type é obrigatório.');
    },
  );

  test('empty error list becomes an unknown error during parsing', () {
    final response = ErrorsResponse.fromJson({'errors': []});

    expect(response.errors.single.title, 'Erro desconhecido');
    expect(
      response.errors.single.detail,
      'Não foi possível processar a resposta.',
    );
  });
}
