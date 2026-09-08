import 'package:cordato/features/core/domain/either.dart';

import 'package:cordato/features/budget/domain/entities/budget_entity.dart';
import 'package:cordato/features/budget/domain/failures/budget_failure.dart';

abstract interface class IBudgetRepository {
  Future<Either<BudgetFailure, void>> create(BudgetEntity budget);
}
