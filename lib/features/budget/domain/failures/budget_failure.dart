sealed class const BudgetFailure(final String message) {
  @override
  String toString() => message;
}

final class const BudgetCreationFailure([
  super.message = 'Não foi possível cadastrar o orçamento.',
]) extends BudgetFailure {}

final class const BudgetOverlappingFailure([
  super.message = 'Já existe um orçamento para esse período.',
]) extends BudgetFailure {}
