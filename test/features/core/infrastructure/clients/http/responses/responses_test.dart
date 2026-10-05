import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

void main() {
  group('response', () {
    test(
      'waits for the request and exposes body and status to the converter',
      () async {
        final pending = Completer<Responses>();
        var executions = 0;
        var conversions = 0;
        final data = response<String>(
          execute: () {
            executions++;
            return pending.future;
          },
          from: (success) {
            conversions++;
            return '${success.statusCode}: ${success.body['name']}';
          },
        );

        expect(executions, 1);
        expect(conversions, 0);
        pending.complete(
          const Right(Reponse(statusCode: 200, body: {'name': 'Gabriel'})),
        );

        expect(conversions, 1);
        expect((await data).right, '200: Gabriel');
      },
    );

    test('supports boolean datas for responses without a body', () async {
      for (final status in [204, 200]) {
        final data = await response<bool>(
          execute: () async => Right(Reponse(statusCode: status, body: {})),
          from: (success) => success.statusCode == 204,
        );

        expect(data.isRight, isTrue);
        expect(data.right, status == 204);
      }
    });

    test(
      'preserves all JSON:API errors without calling the success converter',
      () async {
        final data = await response<String>(
          execute: () async => const Left(
            Reponse(
              statusCode: 422,
              body: {
                'errors': [
                  {
                    'status': '422',
                    'title': 'Nome inválido',
                    'detail': 'Informe um nome.',
                    'source': {'pointer': '/data/attributes/name'},
                  },
                  {'status': '403', 'title': 'Não autorizado'},
                ],
              },
            ),
          ),
          from: (_) => throw StateError('must not convert an error'),
        );

        expect(data.left.errors, hasLength(2));
        expect(data.left.errors.first.status, '422');
        expect(data.left.errors.first.title, 'Nome inválido');
        expect(data.left.errors.last.title, 'Não autorizado');
        expect(data.left.errors.first.detail, 'Informe um nome.');
        expect(data.left.errors.first.pointer, '/data/attributes/name');
      },
    );

    test('preserves the error returned for transport failures', () async {
      final data = await response<int>(
        execute: () async => const Left(
          Reponse(
            statusCode: 0,
            body: {
              'errors': [
                {'title': 'Sem conexão', 'detail': 'Tente novamente.'},
              ],
            },
          ),
        ),
        from: (_) => 1,
      );

      expect(data.left.errors.single.title, 'Sem conexão');
      expect(data.left.errors.single.detail, 'Tente novamente.');
    });

    test(
      'returns an unknown error for malformed or empty error envelopes',
      () async {
        for (final body in <Map<String, dynamic>>[
          {},
          {'errors': []},
          {'errors': 'invalid'},
          {
            'errors': [null],
          },
        ]) {
          final data = await response<int>(
            execute: () async => Left(Reponse(statusCode: 500, body: body)),
            from: (_) => 1,
          );

          expect(data.left.errors.single.title, 'Erro desconhecido');
          expect(
            data.left.errors.single.detail,
            'Não foi possível processar a resposta.',
          );
        }
      },
    );

    test(
      'returns an unknown error for synchronous request exceptions',
      () async {
        final data = await response<int>(
          execute: () => throw StateError('request failed'),
          from: (_) => 1,
        );

        expect(data.left.errors.single.title, 'Erro desconhecido');
      },
    );

    test(
      'returns an unknown error for asynchronous request exceptions',
      () async {
        final data = await response<int>(
          execute: () async => throw StateError('request failed'),
          from: (_) => 1,
        );

        expect(data.left.errors.single.title, 'Erro desconhecido');
      },
    );

    test('returns an unknown error when success conversion fails', () async {
      final data = await response<DateTime>(
        execute: () async => const Right(
          Reponse(statusCode: 200, body: {'created_at': 'invalid'}),
        ),
        from: (success) => DateTime.parse(success.body['created_at'] as String),
      );

      expect(data.left.errors.single.title, 'Erro desconhecido');
    });
  });
}
