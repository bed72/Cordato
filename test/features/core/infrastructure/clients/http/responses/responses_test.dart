import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

void main() {
  group('Responses', () {
    test('preserves status and body', () {
      final body = <String, dynamic>{'name': 'Pessoa'};
      final response = Responses(status: 200, body: body);

      expect(response.status, 200);
      expect(response.body, same(body));
    });
  });

  group('ErrorsResponse', () {
    test('preserves error order and metadata when converting to entities', () {
      final response = ErrorsResponse.fromJson({
        'errors': [
          {
            'status': '422',
            'title': 'Parâmetro inválido',
            'detail': 'Informe o período.',
            'source': {'parameter': 'start_date'},
          },
          {
            'source': {
              'pointer': '/data/attributes/name',
              'parameter': 'filter',
            },
          },
          {'detail': 'Sem origem'},
        ],
      });
      final errors = response.toEntity().errors;

      expect(response.errors, hasLength(3));
      expect(response.errors.first.parameter, 'start_date');
      expect(errors, hasLength(3));
      expect(errors.first.status, '422');
      expect(errors.first.title, 'Parâmetro inválido');
      expect(errors.first.detail, 'Informe o período.');
      expect(errors.first.parameter, 'start_date');
      expect(errors.first.pointer, isNull);
      expect(errors[1].pointer, '/data/attributes/name');
      expect(errors[1].parameter, 'filter');
      expect(errors[1].title, isNull);
      expect(errors.last.detail, 'Sem origem');
      expect(errors.last.pointer, isNull);
      expect(errors.last.parameter, isNull);
    });

    test('uses fallback for an empty error envelope or entity conversion', () {
      final parsed = ErrorsResponse.fromJson({'errors': []});
      final entity = const ErrorsResponse(errors: []).toEntity();

      expect(parsed.errors.single.title, 'Erro desconhecido');
      expect(
        parsed.errors.single.detail,
        'Não foi possível processar a resposta.',
      );
      expect(entity.errors.single.title, 'Erro desconhecido');
    });

    test('rejects malformed JSON instead of hiding parsing failures', () {
      for (final body in <Map<String, dynamic>>[
        {},
        {'errors': 'invalid'},
        {
          'errors': [null],
        },
        {
          'errors': [
            {'status': 422},
          ],
        },
        {
          'errors': [
            {'source': 'invalid'},
          ],
        },
      ]) {
        expect(() => ErrorsResponse.fromJson(body), throwsA(isA<TypeError>()));
      }
    });
  });

  group('HttpResponseException', () {
    test('preserves status and typed errors including an empty list', () {
      const errors = ErrorsResponse(errors: []);
      final exception = HttpResponseException(status: 422, errors: errors);

      expect(exception.status, 422);
      expect(exception.errors, same(errors));
      expect(exception.errors.errors, isEmpty);
    });

    test('parses remote errors while preserving status', () {
      final exception = HttpResponseException.fromResponse(
        const Responses(
          status: 503,
          body: {
            'errors': [
              {'title': 'Sem conexão', 'detail': 'Tente novamente.'},
            ],
          },
        ),
      );

      expect(exception.status, 503);
      expect(exception.errors.errors.single.title, 'Sem conexão');
      expect(exception.errors.errors.single.detail, 'Tente novamente.');
    });

    test('uses fallback for malformed or empty remote envelopes', () {
      for (final body in <Map<String, dynamic>>[
        {},
        {'errors': []},
        {'errors': 'invalid'},
        {
          'errors': [null],
        },
        {
          'errors': [
            {'source': 'invalid'},
          ],
        },
      ]) {
        final exception = HttpResponseException.fromResponse(
          Responses(status: 500, body: body),
        );

        expect(exception.status, 500);
        expect(exception.errors.errors.single.title, 'Erro desconhecido');
        expect(
          exception.errors.errors.single.detail,
          'Não foi possível processar a resposta.',
        );
      }
    });
  });
}
