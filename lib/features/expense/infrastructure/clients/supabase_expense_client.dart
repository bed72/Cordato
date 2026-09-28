import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/infrastructure/enums/expense_create_outcome_enum.dart';

abstract interface class IExpenseClient {
  Future<ExpenseCreateOutcomeEnum> create(ExpenseEntity expense);
}

final class const SupabaseExpenseClient() implements IExpenseClient {
  @override
  Future<ExpenseCreateOutcomeEnum> create(ExpenseEntity expense) async {
    return .failed;
  }
}
