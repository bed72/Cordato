import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

final class ExpensesPreviewRepository({required final GetRepositoryType type})
    implements IExpenseRepository {
  @override
  Future<DeleteRepositoryType> delete({required String id}) async =>
      Left(ErrorsEntity.unknown());

  @override
  Future<GetByIdRepositoryType> getById({required String id}) async =>
      Left(.unknown());

  @override
  Future<GetRepositoryType> get({
    int pageSize = 30,
    DateTime? to,
    DateTime? from,
    String? pageLink,
  }) async => type;

  @override
  Future<UpdateRepositoryType> update({
    required String id,
    int? cents,
    String? description,
    DateTime? occurredOn,
  }) async => Left(.unknown());

  @override
  Future<CreateRepositoryType> create({
    required int cents,
    required String description,
    DateTime? occurredOn,
  }) async => Left(.unknown());
}
