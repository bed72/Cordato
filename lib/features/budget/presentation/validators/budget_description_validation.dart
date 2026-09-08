import 'package:cordato/features/core/presentation/validators/validation.dart';

final class BudgetDescriptionValidation implements Validation<String> {
  const BudgetDescriptionValidation();

  @override
  ValidationResult<String> call(String value) {
    final normalized = value.trim();

    return Valid(normalized);
  }
}
