import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/formatters/error_message_formatter.dart';
import 'package:cordato/features/authentication/presentation/formatters/authentication_error_message_formatter.dart';

abstract final class ResetPasswordErrorMessageFormatter {
  static ({String? password, String? confirmation, String? toast}) fields(
    ErrorsEntity errors,
  ) {
    final passwordMessages = <String>[];
    final confirmationMessages = <String>[];
    final remaining = <ErrorEntity>[];

    for (final error in errors.errors) {
      switch ((error.status, error.pointer)) {
        case ('400', '/password'):
          passwordMessages.add(
            AuthenticationErrorMessageFormatter.format(
              error,
              fallback: 'Confira a senha informada.',
            ),
          );
        case ('400', '/passwordConfirm'):
          confirmationMessages.add(
            AuthenticationErrorMessageFormatter.format(
              error,
              fallback: 'Confira a confirmação da senha.',
            ),
          );
        default:
          remaining.add(error);
      }
    }

    return (
      password: passwordMessages.isEmpty ? null : passwordMessages.join('\n'),
      confirmation: confirmationMessages.isEmpty
          ? null
          : confirmationMessages.join('\n'),
      toast: remaining.isNotEmpty || errors.errors.isEmpty
          ? ErrorMessageFormatter.formatAll(
              remaining,
              fallback: 'Não foi possível redefinir a senha. Tente novamente.',
            )
          : null,
    );
  }
}
