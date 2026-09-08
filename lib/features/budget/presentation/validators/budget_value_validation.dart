import 'package:cordato/features/budget/domain/entities/budget_entity.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';

final class BudgetValueValidation implements Validation<int> {
  const BudgetValueValidation();

  @override
  ValidationResult<int> call(int value) {
    if (value < 1) return const Invalid('Informe um valor maior que zero');
    if (value > BudgetEntity.maxAmount) {
      return const Invalid('Informe um valor dentro do limite permitido');
    }

    return Valid(value);
  }
}
