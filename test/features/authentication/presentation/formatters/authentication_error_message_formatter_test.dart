import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/authentication/presentation/formatters/authentication_error_message_formatter.dart';

void main() {
  const fallback = 'Não foi possível concluir a operação.';

  group('Authentication field messages', () {
    const scenarios = [
      (
        pointer: '/identity',
        code: 'validation_required',
        message: 'Informe seu e-mail.',
      ),
      (
        pointer: '/email',
        code: 'validation_required',
        message: 'Informe seu e-mail.',
      ),
      (
        pointer: '/email',
        code: 'validation_invalid_email',
        message: 'Informe um e-mail válido.',
      ),
      (
        pointer: '/email',
        code: 'validation_not_unique',
        message: 'Este e-mail já está em uso.',
      ),
      (
        pointer: '/password',
        code: 'validation_required',
        message: 'Informe sua senha.',
      ),
      (
        pointer: '/password',
        code: 'validation_length',
        message: 'A senha deve ter entre 6 e 12 caracteres.',
      ),
      (
        pointer: '/password',
        code: 'validation_length_out_of_range',
        message: 'A senha deve ter entre 6 e 12 caracteres.',
      ),
      (
        pointer: '/password',
        code: 'unknown',
        message: 'Confira a senha informada.',
      ),
      (
        pointer: '/passwordConfirm',
        code: 'validation_required',
        message: 'Confirme sua senha.',
      ),
      (
        pointer: '/passwordConfirm',
        code: 'validation_values_mismatch',
        message: 'As senhas não coincidem.',
      ),
      (
        pointer: '/passwordConfirm',
        code: 'unknown',
        message: 'Confira a confirmação da senha.',
      ),
      (
        pointer: '/token',
        code: 'validation_invalid_token',
        message: 'O link é inválido ou expirou. Solicite um novo link.',
      ),
    ];

    for (final scenario in scenarios) {
      test('${scenario.pointer}: ${scenario.code}', () {
        final error = ErrorEntity(
          status: '400',
          pointer: scenario.pointer,
          code: scenario.code,
          title: 'Failed to create record.',
          detail: 'English backend validation message.',
        );

        expect(
          AuthenticationErrorMessageFormatter.format(error, fallback: fallback),
          scenario.message,
        );
      });
    }

    for (final field in ['email', 'password']) {
      test('maps legacy 422 /data/attributes/$field without a detail', () {
        final error = ErrorEntity(
          status: '422',
          pointer: '/data/attributes/$field',
        );

        expect(
          AuthenticationErrorMessageFormatter.format(error, fallback: fallback),
          field == 'email'
              ? 'Informe um e-mail válido.'
              : 'Confira a senha informada.',
        );
      });
    }

    test('maps legacy email conflict without parsing remote text', () {
      const error = ErrorEntity(
        status: '409',
        pointer: '/data/attributes/email',
      );

      expect(
        AuthenticationErrorMessageFormatter.format(error, fallback: fallback),
        'Este e-mail já está em uso.',
      );
    });

    test('unknown fields and codes use the operation fallback', () {
      const error = ErrorEntity(
        status: '400',
        pointer: '/unrecognized',
        code: 'validation_new_rule',
        detail: 'Sensitive backend information.',
      );

      expect(
        AuthenticationErrorMessageFormatter.format(error, fallback: fallback),
        fallback,
      );
    });

    test('does not interpret a server failure as field validation', () {
      const error = ErrorEntity(status: '503', pointer: '/email');

      expect(
        AuthenticationErrorMessageFormatter.format(error, fallback: fallback),
        'O serviço está indisponível no momento. Tente novamente mais tarde.',
      );
    });
  });

  group('Sign-in context', () {
    for (final status in ['400', '401']) {
      test('HTTP $status does not claim an existing session expired', () {
        final error = ErrorEntity(
          status: status,
          detail: 'Failed to authenticate.',
        );

        expect(
          AuthenticationErrorMessageFormatter.signIn(error),
          'Não foi possível entrar. Confira seu e-mail e sua senha.',
        );
      });
    }

    test(
      'HTTP 403 suggests verification without exposing the remote reason',
      () {
        const error = ErrorEntity(status: '403', detail: 'Unverified record.');

        expect(
          AuthenticationErrorMessageFormatter.signIn(error),
          'Não foi possível entrar. Confirme seu e-mail e tente novamente.',
        );
      },
    );

    test('keeps the field-specific required message', () {
      const error = ErrorEntity(
        status: '400',
        pointer: '/password',
        code: 'validation_required',
      );

      expect(
        AuthenticationErrorMessageFormatter.signIn(error),
        'Informe sua senha.',
      );
    });

    test('uses a neutral fallback for unknown failures', () {
      expect(
        AuthenticationErrorMessageFormatter.signIn(
          const ErrorEntity(detail: 'Unexpected error'),
        ),
        'Não foi possível entrar. Tente novamente.',
      );
    });
  });
}
