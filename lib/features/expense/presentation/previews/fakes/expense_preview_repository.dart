import 'package:cordato/features/expense/domain/value_objects/amount_value_object.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';
import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';

import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';

final class ExpensePreviewRepository({required final ExpenseEntity expense})
    implements IExpenseRepository {
  @override
  Future<List<ExpenseSuggestionEntity>> suggestions({
    required String query,
  }) async =>
      [
            ExpenseSuggestionEntity(
              id: 'market',
              description: 'Mercado',
              category: .food,
            ),
            ExpenseSuggestionEntity(
              id: 'rent',
              cents: 160000,
              description: 'Aluguel',
              category: .housing,
            ),
          ]
          .where(
            (item) =>
                item.description.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();

  @override
  Future<ExpenseEntity> getById({required String id}) async => expense;

  @override
  Future<ExpensePageEntity> get({
    String? sort,
    DateTime? to,
    DateTime? from,
    String? category,
    String? pageLink,
    int pageSize = 30,
  }) async => ExpensePageEntity(items: [expense], next: null, prev: null);

  @override
  Future<void> delete({required String id}) async =>
      throw ExpenseException(errors: .unknown());

  @override
  Future<ExpenseEntity> create({
    required int cents,
    required String description,
    ExpenseCategoryEnum category = .other,
    DateTime? occurredOn,
  }) async => ExpenseEntity(
    id: expense.id,
    cents: AmountValueObject.create(cents: cents),
    description: description,
    category: category,
    occurredOn: occurredOn ?? .now(),
  );

  @override
  Future<ExpenseEntity> update({
    required String id,
    ExpenseCategoryEnum? category,
    int? cents,
    String? description,
    DateTime? occurredOn,
  }) async => ExpenseEntity(
    id: id,
    category: category ?? expense.category,
    occurredOn: occurredOn ?? expense.occurredOn,
    description: description ?? expense.description,
    cents: AmountValueObject.create(cents: cents ?? expense.cents.cents),
  );
}
