sealed class BudgetFailure {
  final String message;

  const BudgetFailure(this.message);

  @override
  String toString() => message;
}

final class BudgetCreationFailure extends BudgetFailure {
  const BudgetCreationFailure([
    super.message = 'Não foi possível cadastrar o orçamento.',
  ]);
}

final class BudgetOverlappingFailure extends BudgetFailure {
  const BudgetOverlappingFailure([
    super.message = 'Já existe um orçamento para esse período.',
  ]);
}
