import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/domain/value_objects/amount_value_object.dart';

final class ExpensePreviewRepository({required final ExpenseEntity expense})
    implements IExpenseRepository {
  @override
  Future<GetByIdRepositoryType> getById({required String id}) async =>
      Right(expense);

  @override
  Future<GetRepositoryType> get({int pageSize = 30, String? pageLink}) async =>
      Right(ExpensePageEntity(items: [expense], next: null, prev: null));

  @override
  Future<DeleteRepositoryType> delete({required String id}) async =>
      const Right(false);

  @override
  Future<CreateRepositoryType> create({
    required int cents,
    required String description,
    DateTime? occurredOn,
  }) async => AmountValueObject.create(cents: cents).mapRight(
    (amount) => ExpenseEntity(
      id: expense.id,
      cents: amount,
      description: description,
      occurredOn: occurredOn ?? DateTime.now(),
      category: expense.category,
    ),
  );

  @override
  Future<UpdateRepositoryType> update({
    required String id,
    int? cents,
    String? description,
    DateTime? occurredOn,
  }) async =>
      AmountValueObject.create(cents: cents ?? expense.cents.cents).mapRight(
        (amount) => ExpenseEntity(
          id: id,
          cents: amount,
          description: description ?? expense.description,
          occurredOn: occurredOn ?? expense.occurredOn,
          category: expense.category,
        ),
      );
}
