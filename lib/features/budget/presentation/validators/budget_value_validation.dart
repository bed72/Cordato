import 'package:cordato/features/core/presentation/validators/validation.dart';

final class BudgetValueValidation implements Validation<int> {
  const BudgetValueValidation();

  @override
  ValidationResult<int> call(int value) => value > 0
      ? Valid(value)
      : const Invalid('Informe um valor maior que zero');
}
