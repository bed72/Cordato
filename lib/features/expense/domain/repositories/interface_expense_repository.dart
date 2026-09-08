import 'package:cordato/features/core/domain/either.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/failures/expense_failure.dart';

abstract interface class IExpenseRepository {
  Future<Either<ExpenseFailure, void>> create(ExpenseEntity expense);
}
