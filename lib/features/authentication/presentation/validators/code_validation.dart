import 'package:cordato/features/core/presentation/validators/validation.dart';

final class const CodeValidation() implements Validation<String> {
  static final _pattern = RegExp(r'^[0-9]{6}$');

  @override
  ValidationResult<String> call(String value) {
    final code = value.trim();
    if (code.isEmpty) return const Invalid('Informe o código.');

    return (!_pattern.hasMatch(code))
        ? const Invalid('Informe os 6 dígitos do código.')
        : Valid(code);
  }
}
