import 'package:cordato/features/expense/domain/enums/category_enum.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';

abstract interface class IExpenseRepository {
  Future<void> delete({required int id});
  Future<ExpenseEntity> getById({required int id});
  Future<List<ExpenseSuggestionEntity>> suggestions({required String query});

  Future<ExpensePageEntity> get({
    String? sort,
    DateTime? to,
    DateTime? from,
    String? category,
    int page = 1,
    int pageSize = 30,
  });

  Future<ExpenseEntity> update({
    required int id,
    CategoryEnum? category,
    int? cents,
    String? description,
    DateTime? occurredOn,
  });

  Future<ExpenseEntity> create({
    required int cents,
    required String description,
    CategoryEnum category = .other,
    DateTime? occurredOn,
  });
}
