import 'package:cordato/features/core/presentation/validators/validation.dart';

final class CodeValidation implements Validation<String> {
  const CodeValidation();

  static final _regex = RegExp(r'^\d{6}$');

  @override
  ValidationResult<String> call(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) return const Invalid('Código obrigatório');
    if (!_regex.hasMatch(normalized)) return const Invalid('Código inválido');

    return Valid(normalized);
  }
}
