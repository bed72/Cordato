import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/infrastructure/clients/supabase_expense_client.dart';
import 'package:cordato/features/expense/infrastructure/enums/expense_create_outcome_enum.dart';

abstract interface class IExpenseDataSource {
  Future<ExpenseCreateOutcomeEnum> create(ExpenseEntity expense);
}

final class const ExpenseDataSource({required final IExpenseClient client})
    implements IExpenseDataSource {
  @override
  Future<ExpenseCreateOutcomeEnum> create(ExpenseEntity expense) =>
      client.create(expense);
}
