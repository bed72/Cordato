import 'package:cordato/features/core/presentation/validators/validation.dart';

final class ExpenseDateValidation implements Validation<DateTime?> {
  const ExpenseDateValidation();

  @override
  ValidationResult<DateTime?> call(DateTime? value) {
    if (value == null) return const Invalid('Selecione a data');

    return Valid(value);
  }
}
