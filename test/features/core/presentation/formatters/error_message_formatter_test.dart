import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/formatters/error_message_formatter.dart';

void main() {
  const fallback = 'Não foi possível concluir a solicitação. Tente novamente.';

  group('Shared error messages', () {
    const messages = {
      '401': 'Sua sessão expirou. Entre novamente.',
      '403': 'Você não tem permissão para realizar esta ação.',
      '404': 'Não foi possível encontrar os dados solicitados.',
      '408': 'A resposta demorou mais que o esperado. Tente novamente.',
      '504': 'A resposta demorou mais que o esperado. Tente novamente.',
      '429': 'Muitas tentativas. Aguarde um pouco e tente novamente.',
      '500':
          'O serviço está indisponível no momento. Tente novamente mais tarde.',
      '502':
          'O serviço está indisponível no momento. Tente novamente mais tarde.',
      '503':
          'O serviço está indisponível no momento. Tente novamente mais tarde.',
      '599':
          'O serviço está indisponível no momento. Tente novamente mais tarde.',
    };

    for (final entry in messages.entries) {
      test('maps HTTP ${entry.key} without exposing remote text', () {
        final error = ErrorEntity(
          status: entry.key,
          title: 'Internal server error',
          detail: 'Private diagnostic: token=never-display-this',
        );

        expect(
          ErrorMessageFormatter.format(error, fallback: fallback),
          entry.value,
        );
      });
    }

    for (final status in [
      null,
      '',
      '400',
      '409',
      '422',
      '499',
      '600',
      'invalid',
    ]) {
      test('uses the local fallback for status $status', () {
        final error = ErrorEntity(
          status: status,
          code: 'new_backend_code',
          title: 'Request failed',
          detail: 'Unknown English or sensitive diagnostic.',
        );

        expect(
          ErrorMessageFormatter.format(error, fallback: fallback),
          fallback,
        );
      });
    }

    test('does not trust remote messages even when written in Portuguese', () {
      const error = ErrorEntity(
        title: 'Falha remota',
        detail: 'Dado privado que não deve ser exibido.',
      );

      expect(ErrorMessageFormatter.format(error, fallback: fallback), fallback);
    });
  });

  group('Error collections', () {
    test('uses the operation fallback for an empty collection', () {
      expect(ErrorMessageFormatter.formatAll([], fallback: fallback), fallback);
    });

    test('removes repeated display messages while preserving first occurrence order', () {
      const errors = [
        ErrorEntity(status: '404'),
        ErrorEntity(status: '401'),
        ErrorEntity(status: '404'),
        ErrorEntity(detail: 'Unknown failure'),
      ];

      expect(
        ErrorMessageFormatter.formatAll(errors, fallback: fallback),
        'Não foi possível encontrar os dados solicitados.\n'
        'Sua sessão expirou. Entre novamente.\n$fallback',
      );
      expect(errors, hasLength(4));
    });

    test('keeps the original error and its metadata untouched', () {
      const error = ErrorEntity(
        status: '400',
        code: 'validation_required',
        pointer: '/field',
        parameter: 'field',
        title: 'Request failed',
        detail: 'Missing required value.',
      );
      const errors = ErrorsEntity(errors: [error]);

      ErrorMessageFormatter.formatAll(errors.errors, fallback: fallback);

      expect(errors.errors.single, same(error));
      expect(error.status, '400');
      expect(error.code, 'validation_required');
      expect(error.pointer, '/field');
      expect(error.parameter, 'field');
      expect(error.title, 'Request failed');
      expect(error.detail, 'Missing required value.');
    });
  });
}
