import 'package:cordato/features/core/domain/either.dart';

import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';

import 'package:cordato/features/expense/application/data/create_expense_input.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';
import 'package:cordato/features/expense/infrastructure/remoto/expense_remote_data_source.dart';

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

  @override
  Future<GetRepositoryType> get({int pageSize = 30, String? pageLink}) async {
    try {
      final response = await _remoteDataSource.get(
        pageLink: pageLink,
        pageSize: pageSize > 0 ? pageSize : 30,
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
}
