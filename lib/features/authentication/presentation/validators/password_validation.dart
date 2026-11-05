import 'package:cordato/features/core/presentation/validators/validation.dart';

final class PasswordValidation implements Validation<String> {
  const PasswordValidation();

  static final _digit = RegExp(r'[0-9]');
  static final _uppercase = RegExp(r'[A-Z]');
  static final _lowercase = RegExp(r'[a-z]');

  @override
  ValidationResult<String> call(String value) {
    if (value.isEmpty) return const Invalid('Senha obrigatória');

    final length = value.runes.length;
    if (length < 6 || length > 16) {
      return const Invalid('A senha deve ter entre 6 e 16 caracteres');
    }

    if (!_uppercase.hasMatch(value)) {
      return const Invalid('A senha deve conter uma letra maiúscula');
    }

    if (!_digit.hasMatch(value)) {
      return const Invalid('A senha deve conter um número');
    }

    if (!_lowercase.hasMatch(value)) {
      return const Invalid('A senha deve conter uma letra minúscula');
    }

    return Valid(value);
  }
}
