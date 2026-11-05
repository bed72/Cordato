import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/formatters/error_message_formatter.dart';

abstract final class AuthenticationErrorMessageFormatter {
  static String format(ErrorEntity error, {required String fallback}) {
    if (error.status == '400' ||
        error.status == '409' ||
        error.status == '422') {
      final field = error.pointer?.replaceFirst('/data/attributes', '');
      final required = error.code == 'validation_required';

      switch (field) {
        case '/email' || '/identity':
          if (error.code == 'validation_not_unique' || error.status == '409') {
            return 'Este e-mail já está em uso.';
          }
          return required ? 'Informe seu e-mail.' : 'Informe um e-mail válido.';
        case '/password' || '/passwordConfirm':
          if (error.code == 'validation_values_mismatch') {
            return 'As senhas não coincidem.';
          }
          if (required) {
            return field == '/passwordConfirm'
                ? 'Confirme sua senha.'
                : 'Informe sua senha.';
          }
          if (error.code == 'validation_length_out_of_range' ||
              error.code == 'validation_length') {
            return 'A senha deve ter entre 6 e 16 caracteres.';
          }
          return field == '/passwordConfirm'
              ? 'Confira a confirmação da senha.'
              : 'Confira a senha informada.';
        case '/token':
          return 'O link é inválido ou expirou. Solicite um novo link.';
      }
    }

    return ErrorMessageFormatter.format(error, fallback: fallback);
  }

  static String signIn(ErrorEntity error) {
    if (error.status == '401' ||
        (error.status == '400' && error.pointer == null)) {
      return 'Não foi possível entrar. Confira seu e-mail e sua senha.';
    }
    if (error.status == '403') {
      return 'Não foi possível entrar. Confirme seu e-mail e tente novamente.';
    }

    return format(error, fallback: 'Não foi possível entrar. Tente novamente.');
  }
}
