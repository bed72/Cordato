import 'package:cordato/features/core/domain/either.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/failures/expense_failure.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/infrastructure/remoto/expense_data_source.dart';

final class ExpenseRepository implements IExpenseRepository {
  final IExpenseDataSource dataSource;

  const ExpenseRepository({required this.dataSource});

  @override
  Future<Either<ExpenseFailure, void>> create(ExpenseEntity expense) async {
    final outcome = await dataSource.create(expense);

    return switch (outcome) {
      .created => const Right(null),
      .failed => const Left(ExpenseCreationFailure()),
    };
  }
}
