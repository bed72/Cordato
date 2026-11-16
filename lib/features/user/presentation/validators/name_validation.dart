import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';

final class const NameValidation() implements Validation<String> {
  @override
  ValidationResult<String> call(String value) {
    final normalized = value.trim();
    final length = normalized.runes.length;
    return (length < 2 || length > 32)
        ? const Invalid('O nome deve ter entre 2 e 32 caracteres.')
        : Valid(normalized);
  }

  bool isFieldError(ErrorEntity error) =>
      (error.status == '400' && error.pointer == '/name') ||
      (error.status == '422' && error.pointer == '/data/attributes/name');
}
