import 'package:cordato/features/core/presentation/validators/validation.dart';

final class PasswordConfirmationValidation {
  const PasswordConfirmationValidation();

  ValidationResult<String> call({
    required String password,
    required String confirmation,
  }) {
    if (confirmation.isEmpty) return const Invalid('Confirme a nova senha');
    if (confirmation != password) {
      return const Invalid('As senhas não coincidem');
    }
    return Valid(confirmation);
  }
}
