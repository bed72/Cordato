import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

import 'package:cordato/features/expense/application/data/create_expense_input.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/infrastructure/remoto/expense_remote_data_source.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';

final class ExpenseRepository({
  required final IExpenseRemoteDataSource _remoteDataSource,
}) implements IExpenseRepository {
  @override
  Future<CreateRepositoryType> create({
    required CreateExpenseInput input,
  }) async {
    try {
      final response = await _remoteDataSource.create(input: input);

      return response.fold<CreateRepositoryType>(
        (errors) => Left(errors.toEntity()),
        (expense) => expense.toEntity(),
      );
    } catch (_) {
      return Left(.unknown());
    }
  }
}
