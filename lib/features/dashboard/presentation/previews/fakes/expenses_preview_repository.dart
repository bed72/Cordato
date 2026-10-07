import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/application/data/create_expense_input.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

final class ExpensesPreviewRepository({required final GetRepositoryType type})
    implements IExpenseRepository {
  @override
  Future<DeleteRepositoryType> delete({required String id}) async =>
      Left(ErrorsEntity.unknown());

  @override
  Future<GetRepositoryType> get({int pageSize = 30, String? pageLink}) async =>
      type;

  @override
  Future<CreateRepositoryType> create({
    required CreateExpenseInput input,
  }) async => Left(.unknown());
}
