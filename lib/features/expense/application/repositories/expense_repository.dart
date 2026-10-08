import 'package:cordato/features/core/domain/either.dart';

import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';

import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';
import 'package:cordato/features/expense/infrastructure/remoto/expense_remote_data_source.dart';

final class ExpenseRepository({
  required final IExpenseRemoteDataSource _remoteDataSource,
}) implements IExpenseRepository {
  @override
  Future<GetByIdRepositoryType> getById({required String id}) async {
    try {
      final response = await _remoteDataSource.getById(id: id);

      return response.fold<GetByIdRepositoryType>(
        (errors) => Left(errors.toEntity()),
        (expense) => expense.toEntity(),
      );
    } catch (_) {
      return Left(.unknown());
    }
  }

  @override
  Future<DeleteRepositoryType> delete({required String id}) async {
    try {
      final response = await _remoteDataSource.delete(id: id);

      return response.either(
        (errors) => errors.toEntity(),
        (deleted) => deleted,
      );
    } catch (_) {
      return Left(.unknown());
    }
  }

  @override
  Future<UpdateRepositoryType> update({
    required String id,
    int? cents,
    String? description,
    DateTime? occurredOn,
  }) async {
    try {
      final response = await _remoteDataSource.update(
        id: id,
        cents: cents,
        description: description,
        occurredOn: occurredOn,
      );

      return response.fold<UpdateRepositoryType>(
        (errors) => Left(errors.toEntity()),
        (expense) => expense.toEntity(),
      );
    } catch (_) {
      return Left(.unknown());
    }
  }

  @override
  Future<CreateRepositoryType> create({
    required int cents,
    required String description,
    DateTime? occurredOn,
  }) async {
    try {
      final response = await _remoteDataSource.create(
        cents: cents,
        occurredOn: occurredOn,
        description: description,
      );

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
