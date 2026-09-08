import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';

final class ExpenseValueValidation implements Validation<int> {
  const ExpenseValueValidation();

  @override
  ValidationResult<int> call(int value) {
    if (value < 1) return const Invalid('Informe um valor maior que zero');
    if (value > ExpenseEntity.maxAmount) {
      return const Invalid('Informe um valor dentro do limite permitido');
    }

    return Valid(value);
  }
}
