import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/formatters/error_message_formatter.dart';

abstract final class AuthenticationErrorMessageFormatter {
  static bool isEmailError(ErrorEntity error) =>
      (error.status == '400' || error.status == '422') &&
      (error.pointer == '/email' ||
          error.parameter == 'email' ||
          error.code == 'user_invalid_email');

  static bool isCodeError(ErrorEntity error) =>
      (error.status == '400' ||
          error.status == '401' ||
          error.status == '422') &&
      (error.code == 'user_invalid_token' ||
          error.pointer == '/secret' ||
          error.parameter == 'secret');

  static String requestCode(ErrorEntity error) {
    if (isEmailError(error)) {
      return 'Informe um e-mail válido.';
    }
    const fallback = 'Não foi possível enviar o código. Tente novamente.';
    return error.status == '401'
        ? fallback
        : ErrorMessageFormatter.format(error, fallback: fallback);
  }

  static String confirmCode(ErrorEntity error) {
    if (isCodeError(error)) {
      return 'Código inválido ou expirado. Confira o código ou solicite outro.';
    }
    if (error.status == '401') {
      return 'Não foi possível confirmar seu acesso. Solicite um novo código.';
    }
    return ErrorMessageFormatter.format(
      error,
      fallback: 'Não foi possível confirmar seu acesso. Tente novamente.',
    );
  }

  static String requestErrors(Iterable<ErrorEntity> errors) => _messages(
    errors,
    requestCode,
    'Não foi possível enviar o código. Tente novamente.',
  );

  static String confirmationErrors(Iterable<ErrorEntity> errors) => _messages(
    errors,
    confirmCode,
    'Não foi possível confirmar seu acesso. Tente novamente.',
  );

  static String _messages(
    Iterable<ErrorEntity> errors,
    String Function(ErrorEntity) format,
    String fallback,
  ) {
    final messages = errors.map(format).toSet();
    return messages.isEmpty ? fallback : messages.join('\n');
  }
}
