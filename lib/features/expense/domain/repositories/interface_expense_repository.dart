import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/application/data/create_expense_input.dart';

typedef CreateRepositoryType = Either<ErrorsEntity, ExpenseEntity>;
typedef GetRepositoryType = Either<ErrorsEntity, ExpensePageEntity>;

abstract interface class IExpenseRepository {
  Future<GetRepositoryType> get({required int pageSize, String? pageLink});

  Future<CreateRepositoryType> create({required CreateExpenseInput input});
}
