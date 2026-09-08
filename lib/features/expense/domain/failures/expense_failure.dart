sealed class ExpenseFailure {
  final String message;

  const ExpenseFailure(this.message);

  @override
  String toString() => message;
}

final class ExpenseCreationFailure extends ExpenseFailure {
  const ExpenseCreationFailure([
    super.message = 'Não foi possível cadastrar o gasto.',
  ]);
}
