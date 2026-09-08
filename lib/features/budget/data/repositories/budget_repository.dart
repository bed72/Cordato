import 'package:cordato/features/core/domain/either.dart';

import 'package:cordato/features/budget/infrastructure/remoto/budget_data_source.dart';

import 'package:cordato/features/budget/domain/entities/budget_entity.dart';
import 'package:cordato/features/budget/domain/failures/budget_failure.dart';
import 'package:cordato/features/budget/domain/repositories/interface_budget_repository.dart';

final class BudgetRepository implements IBudgetRepository {
  final IBudgetDataSource dataSource;

  const BudgetRepository({required this.dataSource});

  @override
  Future<Either<BudgetFailure, void>> create(BudgetEntity budget) async {
    final outcome = await dataSource.create(budget);

    return switch (outcome) {
      .created => const Right(null),
      .failed => const Left(BudgetCreationFailure()),
      .overlapping => const Left(BudgetOverlappingFailure()),
    };
  }
}
