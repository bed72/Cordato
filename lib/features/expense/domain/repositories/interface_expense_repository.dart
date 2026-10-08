import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';

typedef DeleteRepositoryType = Either<ErrorsEntity, bool>;
typedef CreateRepositoryType = Either<ErrorsEntity, ExpenseEntity>;
typedef UpdateRepositoryType = Either<ErrorsEntity, ExpenseEntity>;
typedef GetRepositoryType = Either<ErrorsEntity, ExpensePageEntity>;
typedef GetByIdRepositoryType = Either<ErrorsEntity, ExpenseEntity>;

abstract interface class IExpenseRepository {
  Future<DeleteRepositoryType> delete({required String id});

  Future<GetRepositoryType> get({int pageSize = 30, String? pageLink});

  Future<GetByIdRepositoryType> getById({required String id});

  Future<UpdateRepositoryType> update({
    required String id,
    int? cents,
    String? description,
    DateTime? occurredOn,
  });

  Future<CreateRepositoryType> create({
    required int cents,
    required String description,
    DateTime? occurredOn,
  });
}
