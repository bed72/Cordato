import 'package:cordato/features/core/presentation/validators/validation.dart';

final class BudgetDescriptionValidation implements Validation<String> {
  const BudgetDescriptionValidation();

  @override
  ValidationResult<String> call(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return Valid(normalized);

    if (normalized.runes.length < 2 || normalized.runes.length > 128) {
      return const Invalid('A descrição deve ter entre 2 e 128 caracteres');
    }

    return Valid(normalized);
  }
}
