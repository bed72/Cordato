import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/authentication/presentation/validators/password_validation.dart';

final class const ChangePasswordValidation({
  final PasswordValidation passwordValidation = const PasswordValidation(),
}) {
  ValidationResult<String> current(String value) =>
      value.isEmpty ? const Invalid('Informe sua senha atual') : Valid(value);

  ValidationResult<String> call({
    required String oldPassword,
    required String password,
  }) {
    final passwordCheck = passwordValidation(password);

    if (passwordCheck is Invalid<String>) {
      return passwordCheck;
    }

    if (password == oldPassword) {
      return const Invalid('A nova senha não pode ser igual à senha atual');
    }

    return passwordCheck;
  }
}
