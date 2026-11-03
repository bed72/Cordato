import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';

final class const NameValidation() implements Validation<String> {
  @override
  ValidationResult<String> call(String value) {
    final normalized = value.trim();
    final length = normalized.runes.length;
    if (length < 2 || length > 32) {
      return const Invalid('O nome deve ter entre 2 e 32 caracteres.');
    }
    return Valid(normalized);
  }

  // TODO UIS KNOWS STATUS CODE???
  bool isFieldError(ErrorEntity error) =>
      (error.status == '400' && error.pointer == '/name') ||
      (error.status == '422' && error.pointer == '/data/attributes/name');
}
