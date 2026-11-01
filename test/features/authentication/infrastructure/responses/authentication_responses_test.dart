import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/authentication/infrastructure/responses/sign_in_response.dart';

void main() {
  group('Sign-in response', () {
    test('sign-in reads the PocketBase token and record id', () {
      final response = SignInResponse.fromJson({
        'token': 'fixture-token',
        'record': {
          'id': 'user-id',
          'verified': false,
          'email': 'test@example.com',
        },
      });

      expect(response.userId, 'user-id');
      expect(response.token, 'fixture-token');
    });

    test('sign-in does not require expiration metadata', () {
      final response = SignInResponse.fromJson({
        'token': 'token',
        'record': {'id': 'user'},
      });

      expect(response.token, 'token');
      expect(response.userId, 'user');
    });

    test(
      'sign-in rejects missing or incompatible required response attributes',
      () {
        for (final body in <Map<String, dynamic>>[
          {},
          {'record': []},
          {'token': 'token'},
          {
            'token': 1,
            'record': {'id': 'user'},
          },
          {
            'token': 'token',
            'record': {'id': 1},
          },
          {
            'record': {'id': 'user'},
          },
        ]) {
          expect(
            () => SignInResponse.fromJson(body),
            throwsA(isA<TypeError>()),
          );
        }
      },
    );
  });

  group('HTTP error conversion', () {
    test('JSON API errors preserve order and nullable source metadata', () {
      final response = ErrorsResponse.fromJson({
        'errors': [
          {'detail': 'Outra falha'},
          {
            'status': '422',
            'title': 'Validação',
            'detail': 'E-mail inválido',
            'source': {
              'pointer': '/data/attributes/email',
              'parameter': 'email',
            },
          },
        ],
      });

      final errors = response.toEntity().errors;

      expect(errors, hasLength(2));
      expect(errors.first.status, isNull);
      expect(errors.first.pointer, isNull);
      expect(errors.first.parameter, isNull);
      expect(errors.first.detail, 'Outra falha');
      expect(errors.last.status, '422');
      expect(errors.last.title, 'Validação');
      expect(errors.last.parameter, 'email');
      expect(errors.last.detail, 'E-mail inválido');
      expect(errors.last.pointer, '/data/attributes/email');
    });

    test('an empty backend error list has a safe fallback', () {
      final errors = ErrorsResponse.fromJson({'errors': []}).toEntity().errors;

      expect(errors.single.title, 'Erro desconhecido');
      expect(errors.single.detail, 'Não foi possível processar a resposta.');
    });
  });
}
