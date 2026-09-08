import 'package:cordato/features/core/presentation/validators/validation.dart';

final class ExpenseValueValidation implements Validation<int> {
  const ExpenseValueValidation();

  @override
  ValidationResult<int> call(int value) {
    if (value < 1) return const Invalid('Informe um valor maior que zero');

    return Valid(value);
  }
}
