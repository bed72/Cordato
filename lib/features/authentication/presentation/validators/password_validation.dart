import 'package:cordato/features/core/presentation/validators/validation.dart';

final class PasswordValidation implements Validation<String> {
  const PasswordValidation();

  static final _digit = RegExp(r'[0-9]');
  static final _uppercase = RegExp(r'[A-Z]');

  @override
  ValidationResult<String> call(String value) {
    if (value.isEmpty) return const Invalid('Senha obrigatória');

    if (value.length < 6 || value.length > 12) {
      return const Invalid('A senha deve ter entre 6 e 12 caracteres');
    }

    if (!_uppercase.hasMatch(value)) {
      return const Invalid('A senha deve conter uma letra maiúscula');
    }

    if (!_digit.hasMatch(value)) {
      return const Invalid('A senha deve conter um número');
    }

    return Valid(value);
  }
}
