import 'dart:async';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';
import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';

import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';

final class ExpensesListPreviewRepository({
  required final List<ExpenseEntity> items,
  final bool loading = false,
  final ErrorsEntity? failure,
}) implements IExpenseRepository {
  @override
  Future<List<ExpenseSuggestionEntity>> suggestions({
    required String query,
  }) async => [];

  @override
  Future<ExpensePageEntity> get({
    String? sort,
    DateTime? to,
    DateTime? from,
    String? category,
    String? pageLink,
    int pageSize = 30,
  }) async {
    if (loading) return Completer<ExpensePageEntity>().future;
    if (failure != null) throw ExpenseException(errors: failure!);

    final filtered = items.where((expense) {
      final day = _civilDay(expense.occurredOn);

      return (from == null || !day.isBefore(_civilDay(from))) &&
          (category == null || expense.category.value == category) &&
          (to == null || !day.isAfter(_civilDay(to)));
    }).toList();

    if (sort == 'occurred_on') {
      filtered.sort(
        (left, right) =>
            _civilDay(left.occurredOn).compareTo(_civilDay(right.occurredOn)),
      );
    }

    final offset = pageLink == null
        ? 0
        : int.parse(Uri.parse(pageLink).queryParameters['offset']!);
    final page = filtered.skip(offset).take(pageSize).toList();
    final end = offset + page.length;

    return ExpensePageEntity(
      prev: null,
      items: page,
      next: end < filtered.length ? '?offset=$end' : null,
    );
  }

  @override
  Future<ExpenseEntity> getById({required String id}) async {
    final expense = items.where((expense) => expense.id == id).firstOrNull;
    if (expense == null) throw ExpenseException(errors: .unknown());
    return expense;
  }

  @override
  Future<void> delete({required String id}) async =>
      throw ExpenseException(errors: .unknown());

  @override
  Future<ExpenseEntity> create({
    required int cents,
    required String description,
    ExpenseCategoryEnum category = .other,
    DateTime? occurredOn,
  }) async => throw ExpenseException(errors: .unknown());

  @override
  Future<ExpenseEntity> update({
    required String id,
    ExpenseCategoryEnum? category,
    int? cents,
    String? description,
    DateTime? occurredOn,
  }) async => throw ExpenseException(errors: .unknown());

  DateTime _civilDay(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);
}
