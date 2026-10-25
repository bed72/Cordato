import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';

abstract interface class IExpenseRepository {
  Future<void> delete({required String id});

  Future<ExpensePageEntity> get({
    String? sort,
    int pageSize = 30,
    DateTime? to,
    DateTime? from,
    String? category,
    String? pageLink,
  });

  Future<ExpenseEntity> getById({required String id});

  Future<ExpenseEntity> update({
    required String id,
    int? cents,
    String? description,
    DateTime? occurredOn,
  });

  Future<ExpenseEntity> create({
    required int cents,
    required String description,
    DateTime? occurredOn,
  });
}
