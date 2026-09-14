import 'package:cordato/features/core/domain/either.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/failures/expense_failure.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

final class ExpensePreviewRepository implements IExpenseRepository {
  const ExpensePreviewRepository();

  @override
  Future<Either<ExpenseFailure, void>> create(ExpenseEntity expense) async =>
      const Right<ExpenseFailure, void>(null);
}
