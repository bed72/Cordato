import 'package:cordato/features/core/domain/either.dart';

import 'package:cordato/features/budget/domain/entities/budget_entity.dart';
import 'package:cordato/features/budget/domain/failures/budget_failure.dart';
import 'package:cordato/features/budget/domain/repositories/interface_budget_repository.dart';

final class BudgetPreviewRepository implements IBudgetRepository {
  const BudgetPreviewRepository();

  @override
  Future<Either<BudgetFailure, void>> create(BudgetEntity budget) async =>
      const Right<BudgetFailure, void>(null);
}
