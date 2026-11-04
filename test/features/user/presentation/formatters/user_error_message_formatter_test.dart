import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/user/presentation/formatters/user_error_message_formatter.dart';

void main() {
  const fallback = 'Não foi possível atualizar o nome.';

  group('User error messages', () {
    const scenarios = {
      'validation_required': 'Informe seu nome.',
      'validation_length': 'O nome deve ter entre 2 e 32 caracteres.',
      'validation_length_out_of_range':
          'O nome deve ter entre 2 e 32 caracteres.',
      'unknown': 'Confira o nome informado.',
    };

    for (final entry in scenarios.entries) {
      for (final source in [
        (status: '400', pointer: '/name'),
        (status: '422', pointer: '/data/attributes/name'),
      ]) {
        test('${source.status} ${source.pointer}: ${entry.key}', () {
          final error = ErrorEntity(
            status: source.status,
            pointer: source.pointer,
            code: entry.key,
            title: 'Failed to update record.',
            detail: 'Invalid name.',
          );

          expect(
            UserErrorMessageFormatter.format(error, fallback: fallback),
            entry.value,
          );
        });
      }
    }

    test('handles missing remote messages', () {
      expect(
        UserErrorMessageFormatter.format(
          const ErrorEntity(status: '400', pointer: '/name'),
          fallback: fallback,
        ),
        'Confira o nome informado.',
      );
    });

    test('unknown field uses a local fallback', () {
      expect(
        UserErrorMessageFormatter.format(
          const ErrorEntity(
            status: '400',
            pointer: '/avatar',
            detail: 'Invalid avatar.',
          ),
          fallback: fallback,
        ),
        fallback,
      );
    });

    test('server failures do not become name validation failures', () {
      expect(
        UserErrorMessageFormatter.format(
          const ErrorEntity(status: '500', pointer: '/name'),
          fallback: fallback,
        ),
        'O serviço está indisponível no momento. Tente novamente mais tarde.',
      );
    });
  });
}
