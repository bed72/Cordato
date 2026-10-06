import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

import 'package:cordato/features/expense/application/data/create_expense_input.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/infrastructure/remoto/expense_remote_data_source.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';

final class ExpenseRepository({
  required final IExpenseRemoteDataSource _remoteDataSource,
}) implements IExpenseRepository {
  @override
  Future<GetRepositoryType> get({
    required int pageSize,
    String? pageLink,
  }) async {
    if (pageSize <= 0) {
      return const Left(
        ErrorsEntity(
          errors: [
            ErrorEntity(
              title: 'Paginação inválida',
              detail: 'Informe uma quantidade de despesas maior que zero.',
            ),
          ],
        ),
      );
    }

    try {
      final response = await _remoteDataSource.get(
        pageSize: pageSize,
        pageLink: pageLink,
      );
      return response.fold<GetRepositoryType>(
        (errors) => Left(errors.toEntity()),
        (page) {
          final items = <ExpenseEntity>[];
          for (final item in page.items) {
            final expense = item.toEntity();
            if (expense.isLeft) return Left(expense.left);
            items.add(expense.right);
          }
          return Right(
            ExpensePageEntity(items: items, next: page.next, prev: page.prev),
          );
        },
      );
    } catch (_) {
      return Left(.unknown());
    }
  }

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
