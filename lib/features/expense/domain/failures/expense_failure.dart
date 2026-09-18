sealed class const ExpenseFailure(final String message) {
  @override
  String toString() => message;
}

final class const ExpenseCreationFailure([
  super.message = 'Não foi possível cadastrar o gasto.',
]) extends ExpenseFailure {}
