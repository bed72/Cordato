import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';

import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';

final class ExpensesPreviewRepository({required final ExpensePageEntity data})
    implements IExpenseRepository {
  @override
  Future<List<ExpenseSuggestionEntity>> suggestions({
    required String query,
  }) async => [];

  @override
  Future<void> delete({required String id}) async =>
      throw ExpenseException(errors: .unknown());

  @override
  Future<ExpenseEntity> getById({required String id}) async =>
      throw ExpenseException(errors: .unknown());

  @override
  Future<ExpensePageEntity> get({
    String? sort,
    int pageSize = 30,
    DateTime? to,
    DateTime? from,
    int page = 1,
    String? category,
  }) async => data;

  @override
  Future<ExpenseEntity> update({
    required String id,
    ExpenseCategoryEnum? category,
    int? cents,
    String? description,
    DateTime? occurredOn,
  }) async => throw ExpenseException(errors: .unknown());

  @override
  Future<ExpenseEntity> create({
    required int cents,
    required String description,
    ExpenseCategoryEnum category = .other,
    DateTime? occurredOn,
  }) async => throw ExpenseException(errors: .unknown());
}
