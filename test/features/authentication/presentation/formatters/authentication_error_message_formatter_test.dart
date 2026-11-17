import 'package:flutter_test/flutter_test.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/authentication/presentation/formatters/authentication_error_message_formatter.dart';

void main() {
  group('Email errors', () {
    for (final error in [
      const ErrorEntity(status: '400', pointer: '/email'),
      const ErrorEntity(status: '422', parameter: 'email'),
      const ErrorEntity(status: '400', code: 'user_invalid_email'),
    ]) {
      test(
        'maps ${error.status}/${error.pointer}/${error.parameter}/${error.code} to the email field',
        () {
          expect(
            AuthenticationErrorMessageFormatter.isEmailError(error),
            isTrue,
          );
          expect(
            AuthenticationErrorMessageFormatter.requestCode(error),
            'Informe um e-mail válido.',
          );
        },
      );
    }
    test('a server failure is not email validation', () {
      const error = ErrorEntity(status: '503', pointer: '/email');
      expect(AuthenticationErrorMessageFormatter.isEmailError(error), isFalse);
      expect(
        AuthenticationErrorMessageFormatter.requestCode(error),
        'O serviço está indisponível no momento. Tente novamente mais tarde.',
      );
    });
  });

  group('Code errors', () {
    for (final error in [
      const ErrorEntity(status: '401', code: 'user_invalid_token'),
      const ErrorEntity(status: '400', pointer: '/secret'),
      const ErrorEntity(status: '422', parameter: 'secret'),
    ]) {
      test(
        'maps ${error.status}/${error.code}/${error.pointer}/${error.parameter} to the code field',
        () {
          expect(
            AuthenticationErrorMessageFormatter.isCodeError(error),
            isTrue,
          );
          expect(
            AuthenticationErrorMessageFormatter.confirmCode(error),
            'Código inválido ou expirado. Confira o código ou solicite outro.',
          );
        },
      );
    }
    test(
      'a server failure is not an invalid code even with a matching type',
      () {
        const error = ErrorEntity(
          status: '503',
          code: 'user_invalid_token',
          pointer: '/secret',
        );
        expect(AuthenticationErrorMessageFormatter.isCodeError(error), isFalse);
        expect(
          AuthenticationErrorMessageFormatter.confirmCode(error),
          'O serviço está indisponível no momento. Tente novamente mais tarde.',
        );
      },
    );
    test('account validation 401 is not claimed to be a rejected code', () {
      const error = ErrorEntity(status: '401', code: 'user_unauthorized');
      expect(AuthenticationErrorMessageFormatter.isCodeError(error), isFalse);
      expect(
        AuthenticationErrorMessageFormatter.confirmCode(error),
        'Não foi possível confirmar seu acesso. Solicite um novo código.',
      );
      expect(
        AuthenticationErrorMessageFormatter.requestCode(error),
        'Não foi possível enviar o código. Tente novamente.',
      );
    });
  });

  group('Safe feedback', () {
    for (final status in ['429', '408', '403']) {
      test('HTTP $status uses local text for both operations', () {
        final error = ErrorEntity(
          status: status,
          title: 'remote-title',
          detail: 'remote-secret',
        );
        expect(
          AuthenticationErrorMessageFormatter.requestCode(error),
          isNot(contains('remote')),
        );
        expect(
          AuthenticationErrorMessageFormatter.confirmCode(error),
          isNot(contains('remote')),
        );
      });
    }
    test('rate limit has a useful local message', () {
      const error = ErrorEntity(status: '429');
      expect(
        AuthenticationErrorMessageFormatter.requestCode(error),
        'Muitas tentativas. Aguarde um pouco e tente novamente.',
      );
    });
    test('empty errors have an operation-specific fallback', () {
      expect(
        AuthenticationErrorMessageFormatter.requestErrors([]),
        'Não foi possível enviar o código. Tente novamente.',
      );
      expect(
        AuthenticationErrorMessageFormatter.confirmationErrors([]),
        'Não foi possível confirmar seu acesso. Tente novamente.',
      );
    });
    test('messages are deduplicated in original order without exposing unknown content', () {
      const errors = [
        ErrorEntity(status: '429'),
        ErrorEntity(status: '429'),
        ErrorEntity(title: 'remote', detail: 'private'),
      ];
      expect(
        AuthenticationErrorMessageFormatter.requestErrors(errors),
        'Muitas tentativas. Aguarde um pouco e tente novamente.\nNão foi possível enviar o código. Tente novamente.',
      );
      expect(
        AuthenticationErrorMessageFormatter.confirmationErrors(errors),
        'Muitas tentativas. Aguarde um pouco e tente novamente.\nNão foi possível confirmar seu acesso. Tente novamente.',
      );
    });
  });
}
