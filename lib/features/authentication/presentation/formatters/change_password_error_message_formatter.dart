import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/formatters/error_message_formatter.dart';
import 'package:cordato/features/authentication/presentation/formatters/authentication_error_message_formatter.dart';

abstract final class ChangePasswordErrorMessageFormatter {
  static String format(ErrorEntity error) {
    if (error.status == '400' && error.pointer == '/oldPassword') {
      return switch (error.code) {
        'validation_required' => 'Informe sua senha atual.',
        'validation_invalid_old_password' => 'A senha atual está incorreta.',
        _ => 'Confira sua senha atual.',
      };
    }
    return AuthenticationErrorMessageFormatter.format(
      error,
      fallback: 'Não foi possível alterar a senha. Tente novamente.',
    );
  }

  static ({
    String? toast,
    String? current,
    String? password,
    String? confirmation,
  })
  fields(ErrorsEntity errors) {
    final current = <String>[];
    final password = <String>[];
    final confirmation = <String>[];
    final remaining = <ErrorEntity>[];
    for (final error in errors.errors) {
      if (error.status == '400') {
        switch (error.pointer) {
          case '/oldPassword':
            current.add(format(error));
            continue;
          case '/password':
            password.add(format(error));
            continue;
          case '/passwordConfirm':
            confirmation.add(format(error));
            continue;
        }
      }
      remaining.add(error);
    }
    return (
      current: current.isEmpty ? null : current.join('\n'),
      password: password.isEmpty ? null : password.join('\n'),
      confirmation: confirmation.isEmpty ? null : confirmation.join('\n'),
      toast: remaining.isNotEmpty || errors.errors.isEmpty
          ? ErrorMessageFormatter.formatAll(
              remaining,
              fallback: 'Não foi possível alterar a senha. Tente novamente.',
            )
          : null,
    );
  }
}
