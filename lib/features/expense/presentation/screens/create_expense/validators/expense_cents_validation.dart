import 'package:cordato/features/core/presentation/validators/validation.dart';

final class ExpenseCentsValidation implements Validation<int> {
  const ExpenseCentsValidation();

  @override
  ValidationResult<int> call(int value) {
    if (value <= 0) return const Invalid('Informe um valor maior que zero');

    return Valid(value);
  }
}
