import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/application/data/create_expense_input.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

final class ExpensesPreviewRepository({required final GetRepositoryType result})
    implements IExpenseRepository {
  @override
  Future<GetRepositoryType> get({
    required int pageSize,
    String? pageLink,
  }) async => result;

  @override
  Future<CreateRepositoryType> create({
    required CreateExpenseInput input,
  }) async => Left(ErrorsEntity.unknown());
}
