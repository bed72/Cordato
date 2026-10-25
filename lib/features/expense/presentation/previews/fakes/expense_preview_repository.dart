import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/domain/value_objects/amount_value_object.dart';

final class ExpensePreviewRepository({required final ExpenseEntity expense})
    implements IExpenseRepository {
  @override
  Future<ExpenseEntity> getById({required String id}) async => expense;

  @override
  Future<ExpensePageEntity> get({
    String? sort,
    int pageSize = 30,
    DateTime? to,
    DateTime? from,
    String? category,
    String? pageLink,
  }) async => ExpensePageEntity(items: [expense], next: null, prev: null);

  @override
  Future<void> delete({required String id}) async =>
      throw ExpenseException(errors: .unknown());

  @override
  Future<ExpenseEntity> create({
    required int cents,
    required String description,
    DateTime? occurredOn,
  }) async => ExpenseEntity(
    id: expense.id,
    cents: AmountValueObject.create(cents: cents),
    description: description,
    category: expense.category,
    occurredOn: occurredOn ?? .now(),
  );

  @override
  Future<ExpenseEntity> update({
    required String id,
    int? cents,
    String? description,
    DateTime? occurredOn,
  }) async => ExpenseEntity(
    id: id,
    cents: AmountValueObject.create(cents: cents ?? expense.cents.cents),
    category: expense.category,
    occurredOn: occurredOn ?? expense.occurredOn,
    description: description ?? expense.description,
  );
}
